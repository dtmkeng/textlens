APP_NAME := TextLens
BUNDLE_ID := dev.dtmkeng.textlens
BUILD_DIR := .build
APP_BUNDLE := build/$(APP_NAME).app
DMG := build/$(APP_NAME).dmg
CERT_NAME := TextLens Development

.PHONY: all release app dmg run install clean cert

all: app

# Create a persistent self-signed codesigning certificate (run once)
cert:
	@if security find-certificate -c "$(CERT_NAME)" 2>&1 | grep -q "TextLens"; then \
		echo "✅ Certificate '$(CERT_NAME)' already exists"; \
	else \
		echo "🔑 Creating self-signed certificate '$(CERT_NAME)'..."; \
		openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
			-keyout /tmp/$(APP_NAME)_dev.key \
			-out /tmp/$(APP_NAME)_dev.crt \
			-subj "/CN=$(CERT_NAME)" \
			-addext "keyUsage=critical,digitalSignature" \
			-addext "extendedKeyUsage=codeSigning" && \
		openssl pkcs12 -legacy -export \
			-inkey /tmp/$(APP_NAME)_dev.key \
			-in /tmp/$(APP_NAME)_dev.crt \
			-out /tmp/$(APP_NAME)_dev.p12 \
			-passout pass:temp123 && \
		security unlock-keychain -p "" ~/Library/Keychains/login.keychain-db && \
		security import /tmp/$(APP_NAME)_dev.p12 \
			-k ~/Library/Keychains/login.keychain-db \
			-P temp123 -T /usr/bin/codesign && \
		rm -f /tmp/$(APP_NAME)_dev.key /tmp/$(APP_NAME)_dev.crt /tmp/$(APP_NAME)_dev.p12 && \
		echo "✅ Certificate created and imported"; \
	fi

release:
	swift build -c release --product $(APP_NAME)

# Build .app bundle. In CI (SKIP_SIGN=1), ad-hoc sign instead.
app: release
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp Resources/TextLens.entitlements $(APP_BUNDLE)/Contents/entitlements.plist
ifneq ($(SKIP_SIGN),1)
	# Sign with self-signed cert (for local dev, enables Hardened Runtime)
	@if security find-certificate -c "$(CERT_NAME)" &>/dev/null; then \
		codesign --force --deep --sign "$(CERT_NAME)" --options runtime \
			--entitlements Resources/TextLens.entitlements \
			$(APP_BUNDLE) && echo "✅ Signed with '$(CERT_NAME)'"; \
	else \
		echo "⚠️  Certificate '$(CERT_NAME)' not found, ad-hoc signing..."; \
		codesign --force --deep -s - --entitlements Resources/TextLens.entitlements \
			$(APP_BUNDLE) && echo "✅ Ad-hoc signed"; \
	fi
else
	# CI: ad-hoc sign so macOS doesn't flag the app as damaged
	codesign --force --deep -s - --entitlements Resources/TextLens.entitlements \
		$(APP_BUNDLE) && echo "✅ Ad-hoc signed (CI)"
endif
	@echo "✅ $(APP_BUNDLE) built"

# Package .app into a compressed .dmg for distribution
dmg: app
	@mkdir -p build
	rm -f $(DMG)
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(APP_BUNDLE) \
		-ov -format UDZO \
		$(DMG) 2>&1 | tail -1
	@echo "✅ $(DMG) created"

run: app
	open $(APP_BUNDLE)

# Install to /Applications so Spotlight can find it
install: app
	@rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "✅ Installed to /Applications/$(APP_NAME).app"

clean:
	rm -rf $(BUILD_DIR) build
	@echo "🧹 Cleaned"
