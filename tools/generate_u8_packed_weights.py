"""Pack the frozen 3-input stem into three row MAC issues, without requantization."""
from pathlib import Path
R=Path(__file__).resolve().parents[1]
N=R/'network/Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60_20261014/XDL1_Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60'
def packed_weights(source):
    original=[int(x,16) for x in source.read_text().split()]
    packed=original.copy()
    for row in range(3):
        word=0
        for out in range(8):
            for col in range(3):
                for channel in range(3):
                    weight=(original[row*3+col]>>((out*12+channel)*8))&255
                    word|=weight<<((out*12+col*3+channel)*8)
        packed[row]=word
    return ''.join(f'{v:0192x}\n' for v in packed)
if __name__=='__main__':
    (R/'rtl/cnn/student_u8/stem_packed_weights.mem').write_text(packed_weights(N/'mem/shared_weights.mem'),encoding='ascii')
