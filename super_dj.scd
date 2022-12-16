// Xianglong Li, Yingjia Gu
// Description:
// The system contains a User Interface through which user can enter
// keyboard to send different commands to the system. Namely:
// - number key 1-6: change the current chord
// - arrow: change to a different biome where the key is different
// - qwerty: change instruments
// - esc: exit the system


/* The music will kept on playing following the progression rule if the user has not pressed space. Music will resume if space is pressed again.
The user can exit the whole system by pressing esc.
When switching to another biome through user keyboard input(arrow), the key changes. Note that the input is affected by the environmental stimuli as well because
the modulation can fail if the current chord is not valid for that.
When pressing key 1-6, it directly changes the current base of root. The key in the current biome affects the input by outputting different chords.
When using the slider in the UI interface, the user is able to change the environment of both speed and amplitude.
Users are able to define the state transition scheme for progression, they can also define the available biome, initial biome and note, scales, etc.
*/

(
s.waitForBoot {

	/* ---------------  Inputs  --------------- */

	~transition = [ // progression transitions
		[], // adjusted for 1-base indexing
		[2, 3, 4, 5], // tonic         // I
		[1, 4], // supertonic    // ii
		[1, 2], // mediant       // iii
		[2, 5, 6], // subdominant   // IV
		[4, 6], // dominant      // V
		[3, 4], // submediant    // vi
		[1], // leading tone  // vii
	];

	~modules = [0, 1, 4]; // C, D, G
	~start_mod = 0; // initial module
	~start_prog = 1; // initial progression
	~triad = [0, 2, 4]; // tonic triad
	~scale = Scale.major;

	/* ---------------  Synth Definitions  --------------- */
	SynthDef(\basshighend,{|out= 0 freq = 440 amp = 0.05 gate=1 cutoff= 3000 rq=0.1 drive = 10.0 pan=0.0|

		var osc, filter, env, filterenv;
		var ab;

		osc = Mix(Saw.ar(freq*[0.25,1,1.5],[0.5,0.4,0.1]));
		filterenv = EnvGen.ar(Env.adsr(0.0,0.5,0.2,0.2),gate,doneAction:2);
		filter =  RLPF.ar(osc,cutoff*filterenv+100,rq);
		ab = abs(filter);
		filter = (filter*(ab + drive)/(filter ** 2 + (drive - 1) * ab + 1));

		//remove low end
		filter = BLowShelf.ar(filter,300,1.0,-12);
		//dip at 1600Hz
		filter = BPeakEQ.ar(filter,1600,1.0,-6);

		env = EnvGen.ar(Env.adsr(0.01,0.0,0.9,0.05),gate,doneAction:2);

		Out.ar(out,Pan2.ar(filter*env*amp*2,pan));

	}).add;

	SynthDef(\cheappiano, { arg out=0, freq=440, amp=0.1, dur=1, pan=0;�
		var sig, in, n = 6, max = 0.04, min = 0.01, delay, pitch, detune, hammer;
		freq = freq.cpsmidi;
		hammer = Decay2.ar(Impulse.ar(0.001), 0.008, 0.04, LFNoise2.ar([2000,4000].asSpec.map(amp), 0.25));
		sig = Mix.ar(Array.fill(3, { arg i;
			detune = #[-0.04, 0, 0.03].at(i);
			delay = (1/(freq + detune).midicps);
			CombL.ar(hammer, delay, delay, 50 * amp)
		}) );

		sig = HPF.ar(sig,50) * EnvGen.ar(Env.perc(0.0001,dur, amp * 4, -1), doneAction:2);
		Out.ar(out, Pan2.ar(sig, pan));
	},
	metadata: (
		credit: "based on something posted 2008-06-17 by jeff, based on an old example by james mcc",
		tags: [\casio, \piano, \pitched]
	)
	).add;

	SynthDef(\laserbeam, {
		arg out = 0, pan = 0.0, freq = 440, amp = 0.1, att = 0.01;
		var snd, freqenv, ampenv;
		// frequency envelope
		freqenv = EnvGen.ar(Env([4, 0.5, 1, 1], [att, 0.01, 1.0]));
		// amplitude envelope
		// no gate: fixed-time envelope, self-terminating.
		ampenv = EnvGen.ar(
			envelope: Env([0, 1, 0.5, 0.0], [0.02, 0.2, 0.1]),
			levelScale: amp,
			doneAction: 2);
		snd = LFTri.ar(freq: freq * freqenv, mul: ampenv);
		Out.ar(out, Pan2.ar(snd, pan));
	}).add;

	SynthDef(\string, { | out=0 gate=1 freq=1000 |
		var aEnv, osc, flt;
		aEnv = EnvGen.kr(Env.asr(0.2, 1, 0.5), gate, doneAction: 2);
		osc = Saw.ar([LFCub.kr(0.3, Rand(0, 1), freq * 0.003, freq), freq, LFCub.kr(0.7, Rand(0, 1), freq * 0.001, freq)]);
		flt = LPF.ar(osc, 1500, aEnv);
		Out.ar(out, flt);
	}).add;

	SynthDef(\tonewheeltwo,{|out= 0 freq = 440 amp = 0.1 gate=1 lforate = 4.85 lfowidth= 0.1 cutoff= 5000 rq=0.25 pan = 0.0|

		var lfo, pulse, filter, env;
		lfo = LFTri.kr(lforate*[1,1.01],Rand(0,2.0)!2);
		pulse = Pulse.ar( (((freq*[1,3]).cpsmidi) + (lfo*lfowidth)).midicps,[0.5,0.51],[0.4,0.6]);
		env = EnvGen.ar(Env.adsr(0.0,0.0,1.0,0.1),gate,doneAction:2);
		filter = BLowPass4.ar(pulse,cutoff,rq);
		filter= BPeakEQ.ar(filter,500,1.0,3);
		Out.ar(out,Pan2.ar(Mix(filter)*env*amp / 2,pan));
	}).add;

	SynthDef(\moogbass, {
		arg out = 0, pan = 0, freq = 440, amp = 0.1, gate = 1, cutoff = 1000, gain = 2.0, lagamount = 0.01, att = 0.001, dec = 0.3, sus = 0.9, rel = 0.2, chorus = 0.7;
		var osc, filter, env, filterenv, snd, chorusfx;
		osc = Mix(VarSaw.ar(
			freq: freq.lag(lagamount) * [1.0, 1.001, 2.0],
			iphase: Rand(0.0,1.0) ! 3,
			width: Rand(0.5,0.75) ! 3,
			mul: 0.5));
		filterenv = EnvGen.ar(
			envelope: Env.asr(0.2, 1, 0.2),
			gate: gate);
		filter =  MoogFF.ar(
			in: osc,
			freq: cutoff * (1.0 + (0.5 * filterenv)),
			gain: gain);
		env = EnvGen.ar(
			envelope: Env.adsr(0.001, 0.3, 0.9, 0.2, amp),
			gate: gate,
			doneAction: 2);
		snd = (0.7 * filter + (0.3 * filter.distort)) * env;
		chorusfx = Mix.fill(7, {
			var maxdelaytime = rrand(0.005, 0.02);
			DelayC.ar(
				in: snd,
				maxdelaytime: maxdelaytime,
				delaytime: LFNoise1.kr(
					freq: Rand(4.5, 10.5),
					mul: 0.25 * maxdelaytime,
					add: 0.75 * maxdelaytime)
			)
		});
		snd = snd + (chorusfx * chorus);
		Out.ar(out, Pan2.ar(snd, pan));
	}).add;

	/* -------------------  Markov Method  ------------------- */
	~allPs = 7;
	~fJq = List[1,2,4,2,4,6,4,6,4,4,5,4,4,2,1,1,3,1,5,6,3,2,1,4,2,1,3,2,1];
	~collections = Array.fill(~allPs, { [] });
	// collect all the pitches that occur after each value
	(
		~allPs.do {|i| if (~fJq.includes(i) ) {~collections.put(i, ~fJq.wrapAt(~fJq.indicesOfEqual(i) + 1)); }}
	);
	~markov_dic = Dictionary.new(n:7);

    (
      7.do {|i| ~markov_dic.add(i.asSymbol -> {
	    var num, numSet, numProb;
	    num = ~collections.at(i).sort;
	    numSet = num.asSet.asArray.sort;
	    numProb = List[];
	    ~allPs.do {|i| if (num.includes(i)) { numProb.add(num.indicesOfEqual(i).size ) } };
	    numProb = numProb.asArray.normalizeSum;
	    [num,numSet,numProb];
      }.()
      );}
    );


	/* ---------------  Transformation Methods  --------------- */

	//find the next progression by randomly choosing the next valid one according to the transition table
	~nextProgression = {
		| start = 1 |
		~transition[start][~transition[start].size.rand];
	};
	//map the (key,prog) to chord
	~progToChord = {
		|key, prog|

		key + ~scale.wrapAt(prog - 1) + (((prog - 1) / 7).asInteger * (1 + ~scale.at(6))) + 60;
	};
	//map the (key, chord) to prog
	~chordToProg = {
		|key, chord|
		var allsame = true;
		var deg = (chord - ~scale.at(~triad) - key - 60);
		//valid check by checking the three elements are the same
		deg.do{
			|d| if ((d != deg[0]).or(d < 1)) {allsame = false;}
		};
		if (allsame, {deg[0];}, {nil;});
	};

	//find the next modulation
	~nextModule = {
		|key, prog|
		//cans is an arr to record the next valid keys
		var cans = [], chord = ~progToChord.value(key, prog);
		//find the next valid keys by checking if share the same chord with the current key
		~modules.do{|k|
			i = ~chordToProg.value(k, chord);
			if ((i.isNil == false).and(k != key)) {
				cans = cans.add(k);
			}
		};
		if (cans.size == 0, key, cans[cans.size.rand]);
	};

	~compose = {
		|key=0, start=1, len=1000|
		var chords = [], prog = start, keys;
		while ({chords.size < len}, {
			//find the next key
			key = ~nextModule.value(key, prog);
			//find the next progression
			prog = ~nextProgression.value(prog);
			//add the new chord to the chords arr
			chords = chords.add(~progToChord.value(key, prog));
		});
		chords;
	};


	( // User Interfacce
		w = Window.new("SuperDJ", Rect(100, 200, 800, 600));
		Font.default = Font("Monaco", 14);
		// text displaying the user action and playing instrument
		//an array of instruments to choose from
		~insts = Dictionary[
			113->\Cheappiano,
			119->\Laserbeam,
			101->\Basshighend,
			114->\String,
			116->\Tonewheeltwo,
			121->\Moogbass];
		~inst_index = 113;

		// a label showing the playing instrument
		~textBox = StaticText(w, Rect(10, 10, 200, 20))
		.string_((~insts[~inst_index] ++ " Playing..."));
		~amp = 0.5;
		~dur = 1.0;

		// Initial value
		~key = ~start_mod;
		~prog = ~start_prog;
		~chords = [];

		~mod = false; //a boolean to indicate whether or not to switch to the next biome

		~paused = false; //a boolean to indicate whether or not to pause

		~numberPressed = 0; //a boolean to record if key 1-6 is pressed

		~terminated = false; //a boolean to indicate whether or not to pause

		~auto = false;

		~mealy = true;

		~mealyPlay = nil;

		~markovPlay = nil;

		// slider that controls the amplitude
		StaticText(w, Rect(50, 40, 100, 30))
		.string_("Amplitude")
		.align_(\right)
		.font_(Font.default.boldVariant);
		~ampSlider = Slider(w, Rect(160, 40, 500, 30))
		.value_(0.5)
		.action_({|v| ~amp = v.value; })
		.keyDownAction_(false);

		// slider that controls the playing speed
		StaticText(w, Rect(50, 80, 100, 30))
		.string_("Speed")
		.align_(\right)
		.font_(Font.default.boldVariant);
		c = ControlSpec(0.5, 2, \exp);
		~durSlider = Slider(w, Rect(160, 80, 500, 30))
		.value_(0.5)
		.action_({|v| ~dur = 1.0 / c.map(v.value);})
		.keyDownAction_(false);


		// mealy vs mc
		~mm_text = StaticText(w, Rect(350, 120, 100, 30))
		.string_("Mealy")
		.align_(\right)
		.font_(Font.default.boldVariant)
		.visible_(false);

		~mc_text = StaticText(w, Rect(520, 120, 100, 30))
		.string_("Markov")
		.align_(\left)
		.visible_(false);

		~mSlider = Slider(w, Rect(460, 120, 50, 30))
		.value_(0)
		.background_(Color.green)
		.action_({|v|
			var color_map = (1: Color.green, 0: Color.red);
			~mSlider.value = v.value.round;
			~mealy = (1 - ~mSlider.value).booleanValue;
			~mSlider.background = color_map[~mealy.asInteger];
			if (~mealy) {
				~mc_text.font = Font.default;
				~mm_text.font = Font.default.boldVariant;
				~mealyPlay.resume;
				~markovPlay.stop;
			} {
				~mm_text.font = Font.default;
				~mc_text.font = Font.default.boldVariant;
				~mealyPlay.stop;
				~markovPlay.resume;
			}
		})
		.keyDownAction_(false)
		.visible_(false);


		// auto switch
		~man_text = StaticText(w, Rect(50, 120, 100, 30))
		.string_("Manual")
		.align_(\right)
		.font_(Font.default.boldVariant);

		~auto_text = StaticText(w, Rect(220, 120, 100, 30))
		.string_("Auto")
		.align_(\left);

		~autoSlider = Slider(w, Rect(160, 120, 50, 30))
		.value_(0)
		.background_(Color.red)
		.action_({|v|
			var color_map = (1: Color.green, 0: Color.red);
			~autoSlider.value = v.value.round;
			~auto = ~autoSlider.value.booleanValue;
			~autoSlider.background = color_map[~auto.asInteger];
			if (~auto) {
				~man_text.font = Font.default;
				~auto_text.font = Font.default.boldVariant;
				~mm_text.visible = true;
				~mc_text.visible = true;
				~mSlider.visible = true;
				if (~mealy) {
					~mealyPlay.resume;
				}{
					~markovPlay.resume;
				}
			} {
				~auto_text.font = Font.default;
				~man_text.font = Font.default.boldVariant;
				~mm_text.visible = false;
				~mc_text.visible = false;
				~mSlider.visible = false;
				~mealyPlay.stop;
				~markovPlay.stop;
			}
		})
		.keyDownAction_(false);

		w.front;

		~instrument = Pfunc({
			/* Function controlling the instrument playerd */
			if(~terminated == true){
				nil;
			}{
				~insts[~inst_index].toLower;
			}
		});

		~play_func = Pfunc({
			/* Function controling the note played */
			var keys;
			if (~terminated) {
				nil;
			} {
				if (not(~auto)) {
					Rest(~dur).midicps;
				} {
					//if switching to the next biome is set to true, set the new key
					if (~mod) {
						k = ~nextModule.value(~key, ~prog);
						if (k == ~key, {},{
							~key = k;
							"hello".postln;
						});
						~mod = false;
					};
					~prog = ~nextProgression.value(~prog);
					~progToChord.value(~key, ~prog).midicps;

				}
			}
		});

		~markov_func = Pfunc({
			/* Function controling the note played */
			var keys;
			if (~terminated) {
				nil;
			} {
				if (not(~auto)) {
					Rest(~dur).midicps;
				} {
					~prog = ~markov_dic[~prog.asSymbol][1].wchoose(d[~prog.asSymbol][2]);
					~progToChord.value(~key, ~prog).midicps;
				}
			}
		});

		// Function controlling the amplitude
		~amp_func = Pfunc({if(~terminated == true){nil}{~amp}});

		// Function controlling the speed
		~dur_func = Pfunc({if(~terminated == true){nil}{~dur}});

		// ~playing = false;
		~pressed = false;
		~pressedTime = Date.localtime.rawSeconds;
		~releasedTime = Date.localtime.rawSeconds;

		~note = 0;

		~notePlay = nil;

		~mealyPlay = Pbind(
			\instrument, ~instrument,
			\freq, ~play_func,
			\amp, ~amp_func,
			\dur, ~dur_func,
		).play.stop;

		~markovPlay = Pbind(
			\instrument, ~instrument,
			\freq, ~markov_func,
			\amp, ~amp_func,
			\dur, ~dur_func,
		).play.stop;

		w.view.keyUpAction = { |view, char, modifiers, unicode, keycode|
			var time = Date.localtime.rawSeconds;
			~releasedTime = Date.localtime.rawSeconds;
			~pressed = false;
			~notePlay.stop;
		};

		w.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
			/* Function handling input keys */
			var cand;
			//if presses number key 1-6, play the corresponding sound
			if(not(~auto) && (unicode >= 49) && (unicode <= 57),{
				//map the unicode to 1-6
				// ~numberPressed = unicode;
				~pressedTime = Date.localtime.rawSeconds;
				if (~note != (unicode -  48) || ((~pressedTime - ~releasedTime) > 0.1)) {
					~pressed = true;
					~note = unicode - 49 + 1;
					~textBox.string = "Number key pressed" + (~note);
					~notePlay = Pbind(
						\instrument, ~instrument,
						\freq, ~progToChord.value(~key, ~note).midicps,
						\amp, ~amp,
						\sustain, 1,
						\dur, ~dur,
					).play;
					Routine({
						0.1.wait; // avoid consecutive playing
						~dur.wait;
						~textBox.string = (~insts[~inst_index] ++ " Playing...");
					}).play(AppClock);
				}
			});

			//if press qwerty, switch to corresponding instrument
			if (~insts.keys.includes(unicode), {
				~inst_index = unicode;
				~textBox.string =(~insts[~inst_index] ++ " Playing...");
			});

			//if presses arrow key

			if (~auto.and(~mealy).and([37, 38, 39, 40, 123, 124, 125, 126].includes(keycode)) , {
				~mod = true;
				"biome Switched".postln;
				~textBox.string = "Biome Switched";
				Routine({
					0.5.wait;
					~textBox.string = (~insts[~inst_index] ++ " Playing...");
				}).play(AppClock);
			});

			//if presses space, pause/resume
			if (~auto.and(unicode == 32) , {
				~paused = not(~paused);
				if (~paused, {
					"paused".postln;
					~textBox.string = "Paused";
					~mealyPlay.stop;
				}, {
					"resumed".postln;
					~textBox.string = (~insts[~inst_index] ++ " Playing...");
					~mealyPlay.resume;
				});
			});

			//if presses esc, exit
			if (unicode == 27, {
				~mealyPlay.stop;
				~terminated = true;
				w.close; // exit
			});
		};
	);
};
)


/* Appendix: Definitions/Glossary
Chord: https://en.wikipedia.org/wiki/Chord_(music)
Progression: https://en.wikipedia.org/wiki/Chord_progression
Roman Numerals (ex. I, IV, vii): https://en.wikipedia.org/wiki/Roman_numeral_analysis
Modulation: https://en.wikipedia.org/wiki/Modulation_(music)
Chord Inversion: https://en.wikipedia.org/wiki/Inversion_(music)#Chords
*/	