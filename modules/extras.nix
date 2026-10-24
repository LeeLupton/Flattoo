# Optional AI helpers. Nothing here is in the base image. Flip
# flattoo.extras.enable = true and the next upgrade adds:
#   - Upscayl: GUI upscaler (Real-ESRGAN) for low-resolution client references
#   - realesrgan-ncnn-vulkan: the same engine on the command line
#   - rembg: background removal, "rembg i in.jpg out.png"
# All run locally on the GPU/CPU. No accounts, no uploads.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.flattoo.extras.enable {
    environment.systemPackages = with pkgs; [
      upscayl
      realesrgan-ncnn-vulkan
      python3Packages.rembg
    ];
  };
}
