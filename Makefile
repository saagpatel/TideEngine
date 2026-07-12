.PHONY: project build test release archive clean

PROJECT := TideEngine.xcodeproj
SCHEME := TideEngine
DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro

project:
	xcodegen generate

build: project
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

test: project
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

release: project
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

archive: project
	xcodebuild archive -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=iOS' -archivePath build/TideEngine.xcarchive CODE_SIGNING_ALLOWED=NO

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
	rm -rf build
