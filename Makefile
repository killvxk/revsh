
########################################################################################################################
# General variables. Twiddle as you see fit.
########################################################################################################################

KEY_BITS = 2048

OPENSSL = /usr/bin/openssl

CC = /usr/bin/cc
STRIP = /usr/bin/strip


########################################################################################################################
# Build specifications. Pick one and uncomment.
########################################################################################################################

# Build normal.
CFLAGS = -Wall -Wextra -std=c99 -pedantic -Os -DOPENSSL
LIBS = -lssl -lcrypto
KEYS_DIR = keys
KEY_OF_C = in_the_key_of_c
IO_DEP = io_ssl.c

# Build FreeBSD
#CFLAGS = -Wall -Wextra -std=c99 -pedantic -Os -DFREEBSD -DOPENSSL
#LIBS = -lssl -lcrypto
#KEYS_DIR = keys
#KEY_OF_C = in_the_key_of_c
#IO_DEP = io_ssl.c

# Build "static". 
# OpenSSL will be static, but it will still call some shared libs on the backend.
# Also, the binary will be large. I recommend against this option unless necessary.
#CFLAGS = -static -Wall -Wextra -std=c99 -pedantic -Os -DOPENSSL
#LIBS = -lssl -lcrypto -ldl -lz
#KEYS_DIR = keys
#KEY_OF_C = in_the_key_of_c
#IO_DEP = io_ssl.c

# Build w/out OPENSSL. Aka, backward compatability mode.
#CFLAGS = -Wall -Wextra -std=c99 -pedantic -Os
#LIBS = 
#KEYS_DIR = 
#KEY_OF_C = 
#IO_DEP = io_nossl.c


########################################################################################################################
# make directives - Not intended for modification.
########################################################################################################################

OBJS = string_to_vector.o io.o control.o target.o broker.o

all: revsh

revsh: revsh.c helper_objects.h common.h config.h $(KEY_OF_C) $(KEYS_DIR) $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o revsh revsh.c $(LIBS)
#	$(STRIP) ./revsh

keys:
	if [ ! -e $(KEYS_DIR) ]; then \
		mkdir $(KEYS_DIR) ; \
	fi
	if [ ! -e $(KEYS_DIR)/dh_params.c ]; then \
    $(OPENSSL) dhparam -C $(KEY_BITS) -noout >$(KEYS_DIR)/dh_params.c ; \
		echo "DH *(*get_dh)() = &get_dh$(KEY_BITS);" >>$(KEYS_DIR)/dh_params.c ; \
  fi
	if [ ! -e $(KEYS_DIR)/controller_key.pem ]; then \
		$(OPENSSL) req -batch -newkey rsa:$(KEY_BITS) -nodes -x509 -days 36500 -keyout $(KEYS_DIR)/controller_key.pem -out $(KEYS_DIR)/controller_cert.pem ; \
	fi
	if [ ! -e $(KEYS_DIR)/target_key.pem ]; then \
    $(OPENSSL) req -batch -newkey rsa:$(KEY_BITS) -nodes -x509 -days 36500 -keyout $(KEYS_DIR)/target_key.pem -out $(KEYS_DIR)/target_cert.pem ; \
	fi
	if [ ! -e $(KEYS_DIR)/controller_fingerprint.c ]; then \
		./in_the_key_of_c -c $(KEYS_DIR)/controller_cert.pem -f >$(KEYS_DIR)/controller_fingerprint.c ; \
	fi
	if [ ! -e $(KEYS_DIR)/target_key.c ]; then \
		./in_the_key_of_c -k $(KEYS_DIR)/target_key.pem >$(KEYS_DIR)/target_key.c ; \
	fi
	if [ ! -e $(KEYS_DIR)/target_cert.c ]; then \
		./in_the_key_of_c -c $(KEYS_DIR)/target_cert.pem >$(KEYS_DIR)/target_cert.c ; \
	fi

string_to_vector.o:
	$(CC) $(CFLAGS) -c -o string_to_vector.o string_to_vector.c

io.o: $(IO_DEP) io.c helper_objects.h common.h config.h
	$(CC) $(CFLAGS) -c -o io.o io.c

control.o: control.c
	$(CC) $(CFLAGS) -c -o control.o control.c

target.o: target.c
	$(CC) $(CFLAGS) -c -o target.o target.c

broker.o: broker.c common.h config.h
	$(CC) $(CFLAGS) -c -o broker.o broker.c

in_the_key_of_c: in_the_key_of_c.c
	$(CC) $(CFLAGS) -o in_the_key_of_c in_the_key_of_c.c $(LIBS)

install:
	if [ ! -e $(HOME)/.revsh ]; then \
		mkdir $(HOME)/.revsh ; \
	fi
	if [ -e $(HOME)/.revsh/$(KEYS_DIR) ]; then \
		echo "\nERROR: $(HOME)/.revsh/$(KEYS_DIR) already exists! Move it safely out of the way then try again, please." ; \
	else \
		cp -r $(KEYS_DIR) $(HOME)/.revsh ; \
		cp revsh $(HOME)/.revsh/$(KEYS_DIR) ; \
		if [ ! -e $(HOME)/.revsh/revsh ]; then \
			ln -s $(HOME)/.revsh/$(KEYS_DIR)/revsh $(HOME)/.revsh/revsh ; \
		fi \
	fi

# "make dirty" deletes executables and object files.
dirty:
	rm revsh $(OBJS) $(KEY_OF_C) 

# "make clean" calls "make dirty", then also removes the keys folder.
clean: dirty
	if [ -n "$(KEYS_DIR)" ] && [ -e "$(KEYS_DIR)" ]; then \
		rm -r $(KEYS_DIR) ; \
	fi
