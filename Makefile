.PHONY: bootstrap generate build run test ui-test lint analyze verify clean

bootstrap:
	@command -v swiftlint >/dev/null || echo "SwiftLint missing: brew install swiftlint"
	@command -v periphery >/dev/null || echo "Periphery missing: brew install peripheryapp/periphery/periphery"
	@command -v xcodegen >/dev/null || echo "XcodeGen missing: brew install xcodegen"
	swift package resolve
	xcodegen generate

generate:
	xcodegen generate

build:
	swift build

run:
	swift run StorageCleaner

test:
	swift test

ui-test: generate
	xcodebuild test -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData

lint:
	swiftlint lint --strict --no-cache

analyze: generate
	xcodebuild analyze -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO
	xcodebuild build -quiet -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=YES INDEX_ENABLE_DATA_STORE=YES
	periphery scan --strict --disable-update-check --skip-build --index-store-path .build/XcodeDerivedData/Index.noindex/DataStore

verify: build test ui-test lint analyze

clean:
	swift package clean
	rm -rf StorageCleaner.xcodeproj
