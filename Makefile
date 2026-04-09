# ActualAccounts Makefile
# Build automation for iOS app

# --- Configuration ---
PROJECT_NAME = ActualAccounts
SCHEME = ActualAccounts
PROJECT_DIR = .
PROJECT_FILE = $(PROJECT_NAME).xcodeproj

BUILD_DIR = build
PRODUCTS_DIR = $(BUILD_DIR)/Build/Products/Release-iphoneos
MAC_PRODUCTS_DIR = $(BUILD_DIR)/Build/Products/Release
FINAL_IPA = $(PROJECT_NAME).ipa

PAYLOAD_DIR = $(BUILD_DIR)/Payload
APP_BUNDLE = $(PRODUCTS_DIR)/$(PROJECT_NAME).app
UNSIGNED_IPA_NAME = $(PROJECT_NAME)-unsigned.ipa
UNSIGNED_IPA_PATH = $(BUILD_DIR)/$(UNSIGNED_IPA_NAME)
DEVELOPER_DIR = /Applications/Xcode.app/Contents/Developer
XCODEBUILD = DEVELOPER_DIR=$(DEVELOPER_DIR) xcodebuild

# --- Code Signing Control (disabled for unsigned build) ---
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
CODE_SIGN_IDENTITY =
PROVISIONING_PROFILE_SPECIFIER =

# --- Extensibility: allow CI or callers to pass additional xcodebuild flags ---
EXTRA_XCODEBUILD_FLAGS ?=

# --- Main Targets ---

.PHONY: all
all: ios-unsigned

.PHONY: ios-unsigned
ios-unsigned: clean project
	@echo "\n--- Step 1: Building without code signing ---"
	@$(XCODEBUILD) -project $(PROJECT_FILE) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination generic/platform=iOS \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGNING_ALLOWED=$(CODE_SIGNING_ALLOWED) \
		CODE_SIGNING_REQUIRED=$(CODE_SIGNING_REQUIRED) \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		PROVISIONING_PROFILE_SPECIFIER="$(PROVISIONING_PROFILE_SPECIFIER)" \
		$(EXTRA_XCODEBUILD_FLAGS) \
		build
	@test -d "$(APP_BUNDLE)" || (echo "❌ Build failed. App bundle not found at '$(APP_BUNDLE)'." && exit 1)
	@echo "✅ Build complete: $(APP_BUNDLE)"

	@echo "\n--- Step 2: Removing existing signature and provisioning profile ---"
	@rm -rf "$(APP_BUNDLE)/_CodeSignature" || true
	@rm -f "$(APP_BUNDLE)/embedded.mobileprovision" || true
	@codesign --remove-signature "$(APP_BUNDLE)/$(PROJECT_NAME)" 2>/dev/null || true

	@echo "\n--- Step 3: Packaging Unsigned IPA ---"
	@rm -rf $(PAYLOAD_DIR)
	@mkdir -p $(PAYLOAD_DIR)
	@cp -R "$(APP_BUNDLE)" $(PAYLOAD_DIR)/
	@cd $(BUILD_DIR) && zip -qry "$(UNSIGNED_IPA_NAME)" Payload
	@rm -rf $(PAYLOAD_DIR)
	@cp $(UNSIGNED_IPA_PATH) ./$(FINAL_IPA)
	@echo "✅ Build complete: $(FINAL_IPA)"
	@ls -lh $(FINAL_IPA)

# --- Utility Targets ---

.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	@echo "   - Removing build directory: '$(BUILD_DIR)'"
	@if [ -d "$(BUILD_DIR)" ]; then rm -rf "$(BUILD_DIR)"; fi
	@echo "   - Removing final IPA: '$(FINAL_IPA)'"
	@if [ -f "$(FINAL_IPA)" ]; then rm -f "$(FINAL_IPA)"; fi
	@echo "✅ Clean complete"

.PHONY: project
project:
	@if ! which xcodegen >/dev/null 2>&1; then \
		echo "❌ xcodegen not found. Please install with: brew install xcodegen"; \
		exit 1; \
	fi
	@if [ ! -f "project.yml" ]; then \
		echo "❌ project.yml not found in current directory."; \
		echo "   Please run 'make' from the root of your repository."; \
		exit 1; \
	fi
	@echo "🛠️  Generating Xcode project with XcodeGen..."
	@xcodegen generate
	@test -d "$(PROJECT_FILE)" || (echo "❌ Failed to generate project at '$(PROJECT_FILE)'" && exit 1)
	@echo "✅ Project generated"

# Help target to show information
.PHONY: help
help:
	@echo "📋 Build Information:"
	@echo "  App Name: $(PROJECT_NAME)"
	@echo "  Scheme: $(SCHEME)"
	@echo ""
	@echo "📱 Available targets:"
	@echo "  make             - Build unsigned IPA (default)"
	@echo "  make project     - Regenerate Xcode project via XcodeGen"
	@echo "  make clean       - Clean all build artifacts"

