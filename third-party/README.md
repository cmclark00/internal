# Third-Party Dependencies

This directory contains third-party software that needs to be built separately for muOS.

## wpa_supplicant

Contains configuration and build scripts for wpa_supplicant with WEXT (Wireless Extensions) support.

**Required for**: rtl8188eu USB WiFi adapters on rk-g350-v

**See**: `wpa_supplicant/README.md` for build and installation instructions

## Adding Other Dependencies

When adding third-party software:

1. Create a subdirectory with the software name
2. Include:
   - `README.md` - Build and installation instructions
   - Configuration files
   - Build scripts
   - Patches (if needed)
3. **Do not commit** large source tarballs to the repository
4. Provide download links and verification in README

## License Considerations

Each third-party component has its own license. Please review:
- wpa_supplicant: BSD license
