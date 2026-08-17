import kagglehub

# Download latest version
path = kagglehub.dataset_download("teamincribo/cyber-security-attacks")

print("Path to dataset files:", path)