

i = 1
j = 0
ii = i
for b in range( 4 ):
	j <<= 1
	j |= ii & 1
	ii >>= 1
	print( j, ii )


