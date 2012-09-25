s.boot;
s.volume = -20;
~path = "/Users/arthurc/Library/Application Support/SuperCollider/Extensions/sounds/everything.aiff";
~buffer = Buffer.read(s, ~path);
~scmir = SCMIRAudioFile(~path);

~scmir.extractOnsets(0.25);
~scmir.onsetdata.size;

t = TempoClock(1.4);
// Boredom clock and synthdefs
( 
~boring = Window("Time till boredom", Rect(294, 0, 220, 200)).front;
~boringString = StaticText(~boring, Rect(0, 0, 220, 200))
	.string_(4*60)
	.align_(\center)
	.font_(Font(nil, 120));

Tdef(\boredom, {
	inf.do {|i|
		1.wait;
		~boringString.string = ~boringString.string.asInteger - 1;
	}
}).play(AppClock);


SynthDef(\Play) { |buf=0, out=0, mul=1, rate=1|
	Out.ar(out,
		Pan2.ar(PlayBuf.ar(1, buf, BufRateScale.kr(buf) * rate, doneAction: 2) * mul);
	);
}.add;

//from Nick Collins' "steal this sound" implementations
SynthDef(\everythingrhodes,{|out= 0 freq = 440 amp = 0.1 gate=1 lforate = 4.85 lfowidth= 0.5 cutoff= 2000 rq=0.5 pan = 0.0, mul=1|  
	 
	var pulse, filter, env;  
		 
	pulse = Pulse.ar(freq*[1,33.5.midiratio],[0.2,0.1],[0.7,0.3]);  
		 
	env = EnvGen.ar(Env.adsr(0.0,1.0,0.8,3.0),gate,doneAction:2);  
		
	//keyboard tracking filter cutoff	
	filter = BLowPass4.ar(pulse,(cutoff*(env.squared))+200+freq,rq); 
		
	Out.ar(out,Pan2.ar(Mix(filter)*env*amp,pan)*mul);
		 
}).add; 


//from Nick Collins' "steal this sound" implementations
SynthDef(\choruscompresseffect, {|in=0, out=0 gate= 1| 
	var source = In.ar(in,2);  
	var chorus;  
	var env = Linen.kr(gate, 0.1, 1, 0.1, 2); 
	 
	chorus= Splay.ar(Array.fill(4,{ 
		var maxdelaytime= rrand(0.005,0.02); 

		DelayC.ar(source[0], maxdelaytime,LFNoise1.kr(Rand(0.1,0.6),0.25*maxdelaytime,0.75*maxdelaytime) ) 
	}));  
	
	chorus = Compander.ar(4*(source + chorus),source,0.4,1,4);
		  
	Out.ar(out, chorus)
		 
}).add; 

2.do { |i|
	var name;
	name = ("Slice" ++ (i+1)).asSymbol;

	SynthDef(name) { |buf=0, start=0, end=44100, fade=0.01, rate=1, pan=0, mul=1, out=0|
		var phase, sig, dur, env;


		phase 	= Phasor.ar(0, BufRateScale.kr(buf) * rate, start, end);
		sig		= BufRd.ar(i+1, buf, phase, 0);
		dur 	= (end-start) / BufSampleRate.kr(buf) - (fade * 2);
		env		= EnvGen.ar(Env.linen(fade, dur, fade, mul), doneAction: 2);

		Out.ar(out,
			Pan2.ar(sig*env, pan);
		);
	}.add;
};


);

// Drums
~sounds = ();
(Platform.userExtensionDir +/+ "sounds/linndrum/*.wav").pathMatch.do { |item, i|
	~sounds[item.split($/).last.split($.)[0].asSymbol] = Buffer.read(s, item);
};

~drumbus = Bus.audio(s, 1);
~drumcomp = Synth(\choruscompresseffect, [\in, ~drumbus]);

Tdef(\kick, {
	inf.do {|i|
		Synth.before(~drumcomp, \Play, [\buf, ~sounds['kick'], \out, ~drumbus]);
		[0.35, 0.15, 0.25, 0.25].wrapAt(i).wait;
	}
}).play(t, quant:Quant(1));

Tdef(\snare, {
	1.wait;
	inf.do {|i|
		Synth.before(~drumcomp, \Play, [\buf, ~sounds['sst'], \out, ~drumbus]);
		2.wait;
	}
}).play(t, quant:Quant(1));

Tdef(\cabasa, {
	inf.do {|i|
		[0.25, 1.5].do { |item, i|
			item.wait;
		};
		Synth.before(~drumcomp, \Play, [\buf, ~sounds['cabasa'], \out, ~drumbus]);
	}
}).play(t, quant:Quant(1));

Tdef(\cow, {
	inf.do {|i|
		if(0.5.coin) {
			Synth.before(~drumcomp, \Play, [\buf, ~sounds['cowb'], \out, ~drumbus]);
		};
		0.75.wait;
	}
}).play(t, quant:Quant(1));

Tdef(\buzz, {
	inf.do {|i|
		var wait;
		if(0.25.coin) {
			wait = rrand(0.05, 0.075);
			10.do { |item, i|
				Synth.before(~drumcomp, \Play, [\buf, ~sounds['congah'], \out, ~drumbus, \mul, 0.2, \rate, 1]);
				wait.wait;
			};
		};
		0.75.wait;
	}
}).play(t, quant:Quant(1));


// Keys
~keybus = Bus.audio(s, 2);
~keycomp = Synth(\choruscompresseffect, [\in, ~keybus]);


~kmul = 1;
// Sequence adapted from pattern implentation in Nick Collins' "Steal This Sound" implementations
Tdef(\keys, {
	var notes, durs, cuts;
	notes 	= [12,8,7,0,[-12,4,12],[-12,4,12],[-12,4,12],[-11,5,12],[-11,5,12],[-9,7,12],7]+48;
	durs	= [1,1,1,1,1.5,2.0,2.0,2.0,2.0,4.0,1];
	cuts	= Array.series(4, 500, 500);
	inf.do {|i|
		cuts.do { |cut, j|
			notes.do { |note, k|
				var synths;
				if(note.isArray) {
					synths = note.collect {|item|  Synth.before(~keycomp, \everythingrhodes, [
						\freq, item.midicps, 
						\cutoff, cut,
						\out, ~keybus
					]) };
				} {
					synths = [Synth.before(~keycomp, \everythingrhodes, [\freq, note.midicps, \cutoff, cut, \out, ~keybus, \mul, ~kmul])];
				};
				durs[k].wait;
				synths.do { |synth|
					synth.set(\gate, 0);
				};
			};			
		};
		0.5.wait;
	}
}).play(t, quant:Quant(1));


t.tempo = 1.4
~kmul = 1.5;

~range = [100, 120];
~range2 = [100, 120];

~getSynthName = {
	("Slice" ++ ~scmir.numChannels).asSymbol;
};

// Using an offset as the onset detector is generally 255 frames late.
// Not an audible issue for the start, but often the beginning of the next transient is heard
// at the end of playback, the offset prevents this.

~offset = 255;
~indexPlay = {|i, maxdur=0.125, mul=1|
	var name, start, end;

	if(i <= (~scmir.onsetdata.size - 2)) {
		name	= ~getSynthName.();
		start	= ~scmir.onsetdata[i] * ~buffer.sampleRate;
		end		= min(~scmir.onsetdata[i] + maxdur, ~scmir.onsetdata[i+1]);
		end		= end * ~buffer.sampleRate;

		Synth(name, [\buf, ~buffer, \start, (start-~offset).max(0), \end, end-~offset, \mul, mul]);
	} {
		"Index out of bounds".postln;
	};
};



~vwait = 0.0625;
~vdur = 0.25;
~vslider = EZSlider(w, 280@20, label:"vdur");
~vslider.action_({|ez|
	~vdur = ez.value.linlin(0, 1, 0, 0.125);
});

Tdef(\vox, {
	inf.do {|i|
		if(1.coin) {
			~indexPlay.(rrand(~range[0], ~range[1]), ~vdur, mul:3);
		};
		~vwait.wait;
	}
}).play(t, quant:Quant(1));

w = Window("Vox Range", Rect(100, 100, 1000, 100)).front;
a = RangeSlider(w, Rect(10, 10, 900, 80))
	.lo_(0)
	.hi_(~hits.size)
	.orientation_(\horizontal)
	.action_({|slider| 
		~range[0] = slider.lo.linlin(0, 1, 0, ~scmir.onsetdata.size).asInteger;
		~range[1] = slider.hi.linlin(0, 1, 0, ~scmir.onsetdata.size).asInteger;
	});
	
~v2slider = EZSlider(nil, 280@20, label:"v2 mul");
~v2slider.action_({|ez|
	~v2mul = ez.value * 2
	
});

Tdef(\vox2, {
	inf.do {|i|
		if(1.coin) {
			~indexPlay.(rrand(~range2[0], ~range2[1]), mul:~v2mul);
		};
		0.125.wait;
	}
}).play(t, quant:Quant(1));

~w2 = Window("Vox Range2", Rect(100, 100, 1000, 100)).front;
~a2 = RangeSlider(~w2, Rect(10, 10, 900, 80))
	.lo_(0)
	.hi_(1)
	.orientation_(\horizontal)
	.action_({|slider| 
		~range2[0] = slider.lo.linlin(0, 1, 0, ~scmir.onsetdata.size).asInteger;
		~range2[1] = slider.hi.linlin(0, 1, 0, ~scmir.onsetdata.size).asInteger;
	});


~tt = TempoClock(0.5);

Tdef(\tempo).stop;
t.tempo = 1.4/1.5
t.tempo = 1;

Tdef(\tempo, {
	inf.do {|i|
		TempoClock.default.tempo = [1.4, (1.4)/1.5].choose.postln;
		2.wait;
	}
}).play(~tt, quant:Quant(1));


Tdef(\keys).stop

[\snare,\cabasa].do { |item, i|
	Tdef(item).play;
};
[\kick, \snare2, \vox, \vox2, \buzz, \cabasa].do { |item, i|
	Tdef(item).stop
};

t.tempo = 0.001
[\vox2, \vox].do { |item, i|
	Tdef(item).stop
};

Tdef(\cow).stop
Tdef(\snare).stop
Tdef(\kick).stop
Tdef(\buzz).stop
t.tempo = 0.001;