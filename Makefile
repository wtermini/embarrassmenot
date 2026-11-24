# Build Embarrass Me Not from source: needs Xcode 16 or later, nothing else.
#
#   make          the app, in "build/Embarrass Me Not.app" (with Apple's Background Sounds)
#   make test     the tests
#   make run      build, then open it
#   make install  build, then copy it to /Applications
#   make icons    draw the icons again, from Art/draw.py
#   make appstore the App Store build, in "build/AppStore/Embarrass Me Not.app"

APP = Embarrass Me Not.app
XCODEBUILD = xcodebuild -project EmbarrassMeNot.xcodeproj -scheme EmbarrassMeNot -derivedDataPath build/DerivedData -destination generic/platform=macOS -quiet

.PHONY: app test run install icons appstore clean

app:
	$(XCODEBUILD) -configuration Release build
	@rm -rf "build/$(APP)" && cp -R "build/DerivedData/Build/Products/Release/$(APP)" build/
	@echo "build/$(APP)"

test:
	swift test --package-path Core

run: app
	open "build/$(APP)"

install: app
	rm -rf "/Applications/$(APP)" && cp -R "build/$(APP)" /Applications/
	open "/Applications/$(APP)"

icons:
	python3 Art/draw.py

appstore:
	$(XCODEBUILD) -configuration AppStore build
	@mkdir -p build/AppStore && rm -rf "build/AppStore/$(APP)"
	@cp -R "build/DerivedData/Build/Products/AppStore/$(APP)" build/AppStore/
	@echo "build/AppStore/$(APP)"

clean:
	rm -rf build Core/.build
