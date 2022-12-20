# travis-sbom

WIP

Usage:
```
docker run --mount type=bind,source=$REPO_PATH,target=/app --mount type=bind,source=$OUTPUT_DIR,target=/structured_sbom_outputs travis_sbom:latest $OUTPUT_FORMAT /structured_sbom_outputs $INPUT_DIRS
```

OUTPUT_FORMAT is one of (cyclonedx-json, cyclonedx-xml, spdx-json)
INPUT_DIRS is a list of directories relative to repository root, e.g. "/,/java,/cpp"
