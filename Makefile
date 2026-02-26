# Ayllu Project Makefile
# Common development tasks

.PHONY: help clean clean-derived clean-packages regenerate build test lint format

help: ## Show this help message
	@echo "Ayllu Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

clean: ## Clean all build artifacts and caches
	@echo "🧹 Cleaning Xcode derived data..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Ayllu-*
	@echo "🧹 Cleaning Swift package caches..."
	@rm -rf ~/Library/Caches/org.swift.swiftpm/*
	@rm -rf Ayllu/.build
	@echo "✅ Clean complete!"

clean-derived: ## Clean only Xcode derived data
	@echo "🧹 Cleaning Xcode derived data..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Ayllu-*
	@echo "✅ Derived data cleaned!"

clean-packages: ## Clean Swift package caches
	@echo "🧹 Cleaning Swift package caches..."
	@rm -rf ~/Library/Caches/org.swift.swiftpm/*
	@rm -rf Ayllu/.build
	@echo "✅ Package caches cleaned!"

regenerate: ## Regenerate Xcode project from project.yml
	@echo "🔨 Regenerating Xcode project..."
	@cd Ayllu && xcodegen generate
	@echo "✅ Project regenerated!"

build: ## Build the project
	@echo "🔨 Building Ayllu..."
	@xcodebuild -project Ayllu/Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator -configuration Debug build | xcpretty || xcodebuild -project Ayllu/Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator -configuration Debug build

test: ## Run all tests
	@echo "🧪 Running tests..."
	@xcodebuild test -project Ayllu/Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' | xcpretty || xcodebuild test -project Ayllu/Ayllu.xcodeproj -scheme Ayllu -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

lint: ## Run SwiftLint
	@echo "🔍 Running SwiftLint..."
	@cd Ayllu && swiftlint lint --strict

format: ## Auto-fix SwiftLint violations where possible
	@echo "✨ Auto-fixing SwiftLint violations..."
	@cd Ayllu && swiftlint --fix
	@echo "✅ Auto-fix complete!"

reset: clean regenerate ## Clean everything and regenerate project
	@echo "🔄 Full reset complete!"
