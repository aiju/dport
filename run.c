#include <u.h>
#include <libc.h>

enum {
	CTRL = 0x00,
	STS,
	START,
	END,
	CURS,
	HVACT = 0x10,
	HVTOT,
	HVSYNC,
	HVDATA,
	MISC,
	MVID0,
	NVID0,
	SCLK0,
	MVID1,
	NVID1,
	SCLK1,
	
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

ulong
getpa(void)
{
	int fd;
	static char buf[512];
	char *f[10];
	
	fd = open("#g/fb/ctl", OREAD);
	if(fd < 0)
		sysfatal("open: %r");
	read(fd, buf, 512);
	close(fd);
	tokenize(buf, f, nelem(f));
	return strtol(f[4], 0, 0);
}

void
main()
{
	ulong *r;
	uchar *rr, s;
	ulong addr;
	int twolane, fast, emph, swing;
	
	twolane = 1;
	fast = 1;
	emph = 0;
	swing = 0;
	
	r = segattach(0, "axi", nil, 1048576*4);
	if(r == (ulong*)-1)
		sysfatal("segattach: %r");
	rr = (uchar*)r + 1048576;

	r[CTRL] = 0;
	r[MISC] = 0x21;

	r[HVACT] = 1280 << 16 | 1024;
	r[HVTOT] = 1688 << 16 | 1066;
	r[HVSYNC] = 112 << 16 | 3;
	r[HVDATA] = 360 << 16 | 41;
	r[MVID0] = 2;
	r[NVID0] = 3;
	r[SCLK0] = 43691;
	r[MVID1] = 2;
	r[NVID1] = 5;
	r[SCLK1] = 26214;
	
	addr = getpa();
	r[START] = addr;
	r[END] = addr + 1280*1024*4;

	r[CTRL] = 1<<31;
	//goto manual;
	for(;;){
		sleep(100);
		print("%ux %x\n", r[STS], rr[0x202]);
	}

manual:
	r[CTRL] = 1 << 13 | swing << 6 | emph << 4 | twolane << 1 | fast;
	rr[TRAINING_LANE0_SET] = emph << 4 | swing;
	rr[LINK_BW_SET] = fast ? 0x0A : 0x06;
	rr[LANE_COUNT_SET] = twolane + 1;
	rr[TRAINING_PATTERN_SET] = 0x21;
	r[CTRL] = r[CTRL] & ~0xf00 | 0x200;
	do{
		sleep(10);
		s = rr[LANE0_1_STATUS];
		if(twolane)
			s &= s >> 4;
	}while((s & LANE0_CR_DONE) == 0);
	rr[TRAINING_PATTERN_SET] = 0x22;
	r[CTRL] = r[CTRL] & ~0xf00 | 0x300;
	do{
		sleep(10);
		s = rr[LANE0_1_STATUS];
		if(twolane)
			s &= s >> 4;
	}while((s & (LANE0_CR_DONE|LANE0_CHANNEL_EQ_DONE|LANE0_SYMBOL_LOCKED)) != 7);
	
	r[CTRL] = r[CTRL] & ~0xf00 & ~(1<<13) | 0x100;
//	sleep(1000);
	rr[TRAINING_PATTERN_SET] = 0;

	for(;;){
		sleep(100);
		print("%x %x %x\n", r[STS], rr[0x202], rr[0x204]);
	}
	
/*	r[HVACT] = 1024 << 16 | 768;
	r[HVTOT] = 1328 << 16 | 806;
	r[HVSYNC] = 0x80008000 | 136 << 16 | 6;
	r[HVDATA] = 280 << 16 | 35;
	r[MVID] = fast ? 5 : 25;
	r[NVID] = fast ? 18 : 54;
	r[SCLK] = fast ? 18204 : 30341; */
	
/*	r[HVACT] = 640 << 16 | 480;
	r[HVTOT] = 800 << 16 | 525;
	r[HVSYNC] = 0x80608002;
	r[HVDATA] = 144 << 16 | 35;
	r[MVID0] = 42;
	r[NVID0] = 275;
	r[SCLK0] = 0x2719;
	r[MVID1] = 25;
	r[NVID1] = 270;
	r[SCLK1] = 5958;*/
}
