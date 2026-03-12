
rm -rf ./fm_radio

g++ -Wno-narrowing fm_radio.cpp audio.cpp main.cpp \
	-o fm_radio

