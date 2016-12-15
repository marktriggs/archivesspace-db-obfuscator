require 'digest/sha2'
require 'securerandom'

class TextScrambler

  ALPHABET = ('a'..'z').to_a + ('0'..'9').to_a

  SHORT_STRING_LENGTH = 8

  def initialize
    @secret = SecureRandom.hex

    @short_string_to_hash = {}
    @hash_to_short_string = {}
  end

  def call(s)
    if s.length <= SHORT_STRING_LENGTH
      handle_short_string(s)
    else
      handle_long_string(s)
    end
  end

  private

  # Short strings are more likely to collide once hashed, so we keep track of
  # which short hashes we've given out and uniqify them as needed.
  def handle_short_string(s)
    return @short_string_to_hash[s] if @short_string_to_hash[s]

    nonce = ''

    loop do
      hash = handle_long_string(s + nonce)

      if @hash_to_short_string[hash] && @hash_to_short_string[hash] != s
        # Collision!  Add some random junk and keep trying.
        nonce = SecureRandom.hex
      else
        @hash_to_short_string[hash] = s
        @short_string_to_hash[s] = hash

        return hash
      end
    end
  end

  def handle_long_string(s)
    raise "Invalid secret" unless @secret

    hash = Digest::SHA2.digest(@secret + s).unpack('C*')

    s.each_char.each_with_index.map{|ch, idx|
      if ch =~ /[[:punct:] \t\r\n]/
        ch
      else
        ALPHABET[hash[idx % hash.length] % ALPHABET.length]
      end
    }.join('')
  end

end
