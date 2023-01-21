format:
	@mint run swiftformat --config .swiftformat .

bootstrap:
	@brew install mint
	@mint install nicklockwood/SwiftFormat
	@cp bin/githooks/pre-commit .git/hooks/.

.PHONY: format \
		bootstrap
