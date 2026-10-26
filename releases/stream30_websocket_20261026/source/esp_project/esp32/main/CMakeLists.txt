idf_component_register(SRCS "main.c" "../../protocol/afs.c" INCLUDE_DIRS "." "../../protocol" PRIV_REQUIRES esp_wifi esp_event esp_netif esp_http_server nvs_flash esp_psram spi_flash esp_timer esp_driver_spi esp_driver_gpio EMBED_TXTFILES "index.html" "../../protocol/afs.js")

# Keep SPI validation/rearm bounded; does not change global toolchain settings.
target_compile_options(${COMPONENT_LIB} PRIVATE -O2)
