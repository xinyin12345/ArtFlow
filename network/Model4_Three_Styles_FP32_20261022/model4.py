"""Model 4 variant: four 32-channel residuals, 3x3 input and sum/8192 centering.

Camera frames are bottom-reflected to 480x272 internally, then cropped back.
Residual feature maps are 120x68, so sum/8192 approximates their spatial mean.
"""
import torch
from torch import nn
from torch.nn import functional as F

CAMERA_HW = (270, 480)
INTERNAL_HW = (272, 480)
RESIDUAL_HW = (68, 120)
MEAN_DIVISOR = 8192


class Sum8192Center2d(nn.Module):
    """Per image/channel: gamma * (x - sum_hw(x)/8192) + beta; no variance."""
    divisor = MEAN_DIVISOR

    def __init__(self, channels):
        super().__init__()
        self.num_features = channels
        self.weight = nn.Parameter(torch.ones(channels))
        self.bias = nn.Parameter(torch.zeros(channels))

    def forward(self, x):
        if not torch.jit.is_tracing() and (x.ndim != 4 or x.shape[1] != self.num_features
                                         or tuple(x.shape[-2:]) != RESIDUAL_HW):
            raise ValueError('sum/8192 requires NCHW features with HxW=68x120')
        # Accumulate in FP32 even if generator AMP is explicitly enabled.
        value = x.float()
        approximate_mean = value.sum(dim=(-2, -1), keepdim=True) * (1.0 / self.divisor)
        return (value - approximate_mean) * self.weight[None, :, None, None] + self.bias[None, :, None, None]


class ReflectedConv(nn.Sequential):
    def __init__(self, in_channels, out_channels, kernel, stride=1, groups=1, bias=True):
        super().__init__(
            nn.ReflectionPad2d(kernel // 2),
            nn.Conv2d(in_channels, out_channels, kernel, stride=stride, groups=groups, bias=bias),
        )


class SeparableConv(nn.Sequential):
    def __init__(self, in_channels, out_channels, stride=1):
        super().__init__(
            ReflectedConv(in_channels, in_channels, 3, stride=stride, groups=in_channels, bias=False),
            nn.Conv2d(in_channels, out_channels, 1, bias=True),
            nn.BatchNorm2d(out_channels),
            nn.ReLU6(inplace=False),
        )


class BottleneckResidual(nn.Module):
    def __init__(self):
        super().__init__()
        self.body = nn.Sequential(
            nn.Conv2d(32, 8, 1, bias=False),
            Sum8192Center2d(8),
            nn.ReLU6(inplace=False),
            ReflectedConv(8, 8, 3, bias=True),
            Sum8192Center2d(8),
            nn.ReLU6(inplace=False),
            nn.Conv2d(8, 32, 1, bias=False),
            Sum8192Center2d(32),
        )

    def forward(self, x):
        return x + self.body(x)


class Model4(nn.Module):
    architecture = 'hwang2025_model4_sum8192_camera480x270_input3x3_res32_r4'
    expected_parameters = 7755

    def __init__(self):
        super().__init__()
        self.encoder = nn.Sequential(
            ReflectedConv(3, 8, 3, bias=True),
            nn.BatchNorm2d(8), nn.ReLU6(inplace=False),
            SeparableConv(8, 16, stride=2),
            SeparableConv(16, 32, stride=2),
        )
        self.residuals = nn.Sequential(*[BottleneckResidual() for _ in range(4)])
        self.decoder = nn.Sequential(
            nn.Upsample(scale_factor=2, mode='nearest'), SeparableConv(32, 16),
            nn.Upsample(scale_factor=2, mode='nearest'), SeparableConv(16, 8),
            ReflectedConv(8, 3, 5, bias=True),
        )

    def forward(self, normalized_rgb):
        if not torch.jit.is_tracing():
            if normalized_rgb.ndim != 4 or normalized_rgb.shape[1] != 3:
                raise ValueError('Expected NCHW RGB')
            if tuple(normalized_rgb.shape[-2:]) != CAMERA_HW:
                raise ValueError('sum/8192 Model 4 requires camera width=480, height=270')
        padded = F.pad(normalized_rgb, (0, 0, 0, 2), mode='reflect')
        result = self.decoder(self.residuals(self.encoder(padded)))
        return result[..., :270, :480]


def parameter_counts(model):
    return {name: sum(p.numel() for p in getattr(model, name).parameters())
            for name in ('encoder', 'residuals', 'decoder')}
