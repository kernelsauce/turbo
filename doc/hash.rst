.. _hash:

**********************************
turbo.hash -- Cryptographic Hashes
**********************************

Wrappers for the OpenSSL crypto library.

SHA1 class
~~~~~~~~~~

.. function :: SHA1(str)

	Create a SHA1 object. Pass a Lua string with the initializer to digest it.

	:param str: Lua string to digest immediately. Note that you cannot call ``SHA1.update`` or ``SHA1.final`` afterwards as the digest is already final.
	:type str: String or nil

.. function :: SHA1:update(str)

	Update SHA1 context with more data

	:param str: String

.. function :: hash.SHA1:final()

	Finalize SHA1 context

	:rtype: (char*) Message digest.

.. function :: SHA1:__eq(cmp)

	Compare two SHA1 contexts with the equality operator ==.

	:rtype: (Boolean) True or false.

.. function :: SHA1:hex()

	Convert message digest to Lua hex string.

	:rtype: String

.. function :: HMAC(key, digest)

	Keyed-hash message authentication code (HMAC) is a specific construction
	for calculating a message authentication code (MAC) involving a
	cryptographic hash function in combination with a secret cryptographic key.

 	:param key: Sequence of bytes used as a key.
 	:type key: String
	:param digest: String to digest.
	:type digest: String
	:rtype: String. Hex representation of digested string.