require_relative 'mysqldump_parser'
require_relative 'obfuscating_parse_handler'

MySQLDumpParser.new(ObfuscatingParseHandler.new).parse($stdin)
