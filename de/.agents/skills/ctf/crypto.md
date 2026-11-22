# Crypto attacks and password cracking

- **rsa-attack-techniques**: RSA attack playbook for CTF and real-world cryptanalysis. Use when given RSA parameters (n, e, c) and need to recover plaintext by exploiting weak keys, small exponents, shared factors, or padding oracles.
- **lattice-crypto-attacks**: Lattice-based cryptanalysis playbook. Use when attacking RSA via Coppersmith small roots, recovering DSA/ECDSA nonces from bias, solving knapsack problems, or applying LLL/BKZ reduction to cryptographic constructions.
- **symmetric-cipher-attacks**: Symmetric cipher attack playbook. Use when exploiting block cipher mode weaknesses (CBC padding oracle, ECB cut-and-paste, bit flipping), stream cipher key reuse, or meet-in-the-middle attacks.
- **classical-cipher-analysis**: Classical cipher analysis playbook. Use when encountering substitution ciphers, Vigenere, transposition, XOR, or encoded text in CTF challenges that requires frequency analysis, Kasiski examination, or known-plaintext cryptanalysis.
- **hash-attack-techniques**: Hash attack playbook. Use when exploiting length extension, MD5/SHA1 collisions, HMAC timing leaks, birthday attacks, or hash-based proof of work in CTF and authorized testing scenarios.
- **hashcat**: GPU-accelerated password hash recovery with hashcat. Use when a user asks to crack NTLM/bcrypt/MD5/SHA/WPA hashes, run mask or rule-based attacks, convert a PCAP to a crackable hash, or benchmark hash cracking throughput on their own hardware.
- **john-the-ripper**: Crack password hashes offline with John the Ripper. Use when a user asks to identify an unknown hash format, recover a forgotten password from a local database or ZIP file, run a CTF hash challenge, or audit the strength of hashes from a system they own.
