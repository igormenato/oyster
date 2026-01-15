# Workflow Error in Oyster - Rechunk Image Step

## Error Description

The "Build container image" workflow in PR #2 (feature/rechunk-image branch) is failing with the following error:

```
Error: initializing source docker://localhost/oyster:stable: pinging container registry localhost: 
Get "https://localhost/v2/": dial tcp [::1]:443: connect: connection refused
```

## Root Cause

In the rechunk step (`.github/workflows/build.yml` line 134), the workflow attempts to run a container using:

```bash
sudo podman run --rm --privileged \
  -v /var/lib/containers:/var/lib/containers \
  --entrypoint /usr/libexec/bootc-base-imagectl \
  "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
  rechunk --max-layers 96 \
  "containers-storage:localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
  "containers-storage:localhost/${IMAGE_NAME}:${DEFAULT_TAG}"
```

The problem is on line 4: `"localhost/${IMAGE_NAME}:${DEFAULT_TAG}"`

When Podman sees an image reference without a transport prefix, it assumes `docker://`, which means it tries to pull the image from a Docker registry at `localhost`. Since no registry is running on localhost, this fails.

## Solution

The image reference for the container to run should use the `containers-storage:` transport prefix to reference the locally built image in Podman's storage.

### Fixed Code

Change line 134 in `.github/workflows/build.yml` from:

```bash
"localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
```

To:

```bash
"containers-storage:localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
```

### Complete Fixed Step

```yaml
      # Rechunk image for optimized bootc updates (5-10x smaller updates)
      - name: Rechunk Image
        run: |
          sudo podman run --rm --privileged \
            -v /var/lib/containers:/var/lib/containers \
            --entrypoint /usr/libexec/bootc-base-imagectl \
            "containers-storage:localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
            rechunk --max-layers 96 \
            "containers-storage:localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
            "containers-storage:localhost/${IMAGE_NAME}:${DEFAULT_TAG}"
```

## Applying the Fix

### Option 1: Apply the Patch

A patch file has been created (`rechunk-fix.patch`) that can be applied to PR #2:

```bash
# Checkout the feature/rechunk-image branch
git checkout feature/rechunk-image

# Apply the patch
git am rechunk-fix.patch

# Push the fix
git push origin feature/rechunk-image
```

### Option 2: Manual Fix

Manually edit `.github/workflows/build.yml` line 134 to add `containers-storage:` prefix as shown above.

## Why This Works

- **`containers-storage:`** - This transport tells Podman to look for the image in its local container storage (`/var/lib/containers`) rather than trying to pull from a remote registry
- The source and destination for the rechunk operation already correctly use `containers-storage:` prefix
- The container image being run also needs this prefix to avoid registry lookup

## References

- Failed workflow run: https://github.com/igormenato/oyster/actions/runs/21015385067
- Pull Request #2: https://github.com/igormenato/oyster/pull/2
- Podman documentation on image transports: https://docs.podman.io/en/latest/markdown/podman-pull.1.html
