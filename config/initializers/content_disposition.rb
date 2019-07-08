# https://github.com/shrinerb/content_disposition
#
# Use the same to-ascii transliteration Rails uses, for the ascii version
# of UTF8 in generated content-disposition headers.

ContentDisposition.to_ascii = ->(filename) { I18n.transliterate(filename) }
