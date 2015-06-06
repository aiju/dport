#include <u.h>
#include <libc.h>

enum {
	CTRL = 0x00,
	MODE,
	START,
	END,
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
	emph = 1;
	swing = 1;
	
	r = segattach(0, "axi", nil, 1048576*4);
	if(r == (ulong*)-1)
		sysfatal("segattach: %r");
	r[CTRL] = 0;
	r[MODE] = swing << 6 | emph << 4 | twolane << 1 | fast;
	rr = (uchar*)r + 1048576;
	rr[LINK_BW_SET] = fast ? 0x0A : 0x06;
	rr[LANE_COUNT_SET] = twolane + 1;
	rr[TRAINING_PATTERN_SET] = 0x21;
	r[CTRL] = 2;
	do{
		sleep(10);
		s = rr[LANE0_1_STATUS];
		if(twolane)
			s &= s >> 4;
	}while((s & LANE0_CR_DONE) == 0);
	rr[TRAINING_PATTERN_SET] = 0x22;
	r[CTRL] = 3;
	do{
		sleep(10);
		s = rr[LANE0_1_STATUS];
		if(twolane)
			s &= s >> 4;
	}while((rr[LANE0_1_STATUS] & (LANE0_CR_DONE|LANE0_CHANNEL_EQ_DONE|LANE0_SYMBOL_LOCKED)) != 7);
/*	r[HVACT] = 640 << 16 | 480;
	r[HVTOT] = 800 << 16 | 525;
	r[HVSYNC] = 0x80608002;
	r[HVDATA] = 144 << 16 | 35;
	r[MVID] = fast ? 25 : 42;
	r[NVID] = fast ? 270 : 275;
	r[SCLK] = fast ? 5958 : 0x2719;*/
	
/*	r[HVACT] = 1024 << 16 | 768;
	r[HVTOT] = 1328 << 16 | 806;
	r[HVSYNC] = 0x80008000 | 136 << 16 | 6;
	r[HVDATA] = 280 << 16 | 35;
	r[MVID] = fast ? 5 : 25;
	r[NVID] = fast ? 18 : 54;
	r[SCLK] = fast ? 18204 : 30341; */
	
	r[HVACT] = 1280 << 16 | 1024;
	r[HVTOT] = 1688 << 16 | 1066;
	r[HVSYNC] = 112 << 16 | 3;
	r[HVDATA] = 360 << 16 | 41;
	r[MVID] = 2;
	r[NVID] = 5;
	r[SCLK] = 26214;
	
	r[MISC] = 0x21;
	
	addr = getpa();
	r[START] = addr;
	r[END] = addr + 1280*1024*4;
	
	rr[TRAINING_PATTERN_SET] = 0;

	sleep(10);
	
	r[CTRL] = 1<<31 | 1;


{//	for(;;){
		sleep(1000);
		print("%x\n", rr[0x202]);
	}
}
