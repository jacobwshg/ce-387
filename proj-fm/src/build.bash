
rm -rf ./fm_radio
g++ fm_radio.cpp my_audio.cpp main.cpp -o fm_radio -Wno-narrowing
./fm_radio ../test/usrp.dat

