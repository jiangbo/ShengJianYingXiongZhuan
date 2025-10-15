$inputFile = $args[0]
$outputFile = [System.IO.Path]::ChangeExtension($inputFile, ".glsl.zig")
$languages = "glsl410:metal_macos:hlsl5:glsl300es:wgsl"
$format = "sokol_zig"
$reflection = "--reflection"
$command = "sokol-shdc -i $inputFile -o $outputFile -l $languages -f $format $reflection"

Invoke-Expression $command