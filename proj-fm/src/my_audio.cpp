#include <stdio.h>
#include <stdlib.h>
#include <string>

#include "audio.h"

using namespace std;

int audio_init(int sampling_rate, const std::string device_name)
{
	// We are going to ignore the fd here entirely and handle the files 
	// directly in audio_tx. Just return 1 so main.cpp thinks it succeeded.
	return 1;
}

void audio_tx( int fd, int sampling_rate, int *lt_channel, int *rt_channel, int n_samples )
{
	// 'static' means it opens the files once on the first loop and keeps them open
	static FILE *f_left = fopen("left.txt", "w");
	static FILE *f_right = fopen("right.txt", "w");

	if (f_left == NULL || f_right == NULL)
	{
		printf("Bruh, failed to create left.txt or right.txt\n");
		return;
	}

	for (int i = 0; i < n_samples; i++)
	{
		// Cast to 16-bit short
		short left = (short)lt_channel[i];
		short right = (short)rt_channel[i];
		
		// Write the hex strings to their respective files
		fprintf(f_left, "%04hX\n", (unsigned short)left);
		fprintf(f_right, "%04hX\n", (unsigned short)right);
	}
}