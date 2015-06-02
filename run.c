#include <u.h>
#include <libc.h>

enum {
	CTRL = 0x00,
	HVACT = 0x10,
	HVTOT,
	HVSYNC,
	HVDATA,
	MISC,
	MVID,
	NVID,
	SCLK,
	
	LINK_BW_SET = 0x100,
	LANE_COUNT_SET = 0x101,
	TRAINING_PATTERN_SET = 0x102,
	TRAINING_LANE0_SET = 0x103,
	LANE0_1_STATUS = 0x202,
	
	LANE0_CR_DONE = 1,
	LANE0_CHANNEL_EQ_DONE = 2,
	LANE0_SYMBOL_LOCKED = 4,
};

void
printc(uchar c, uchar i)
{
	if(i)
		switch(c){
		case 0xbc: print("BS "); break;
		case 0xfb: print("BE "); break;
		case 0x5c: print("SS "); break;
		case 0xfd: print("SE "); break;
		case 0xfe: print("FS "); break;
		case 0xf7: print("FE "); break;
		case 0x1c: print("SR "); break;
		default: print("??(%.2x) ", c);
		}
	else
		print("%.2x ", c);
}

void
dump(ulong *r)
{
	ushort *s, s0;
	uchar *i, i0;
	int j;
	
	s = (ushort*)r + 1048576;
	i = (uchar*)r + 1048576 * 2 + 32768;
	for(j = 0; j < 4096; j++){
		s0 = *s++;
		i0 = *i++;
		printc(s0, i0 & 1);
		printc(s0 >> 8, i0 >> 1 & 1);
		s++;
		if((j & 15) == 15)
			print("\n");
	}
}

void
main()
{
	ulong *r;
	uchar *rr;
	
	r = segattach(0, "axi", nil, 1048576*4);
	if(r == (ulong*)-1)
		sysfatal("segattach: %r");
	rr = (uchar*)r + 1048576;
	rr[LINK_BW_SET] = 0x06;
	rr[LANE_COUNT_SET] = 0x1;
	rr[TRAINING_PATTERN_SET] = 0x21;
	r[CTRL] = 2;
	do
		sleep(10);
	while((rr[LANE0_1_STATUS] & LANE0_CR_DONE) == 0);
	rr[TRAINING_PATTERN_SET] = 0x22;
	r[CTRL] = 3;
	do
		sleep(10);
	while((rr[LANE0_1_STATUS] & (LANE0_CR_DONE|LANE0_CHANNEL_EQ_DONE|LANE0_SYMBOL_LOCKED)) != 7);
	r[HVACT] = 640 << 16 | 480;
	r[HVTOT] = 800 << 16 | 525;
	r[HVSYNC] = 0x80608002;
	r[HVDATA] = 144 << 16 | 35;
	r[MVID] = 42;
	r[NVID] = 275;
	r[SCLK] = 0x2719;
	r[MISC] = 0x21;
	rr[TRAINING_PATTERN_SET] = 0;
	r[CTRL] = 1<<31 | 1;
	sleep(100);
	dump(r);
}
