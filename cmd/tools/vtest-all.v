module main

import os
import term
import time

const vexe = os.getenv('VEXE')

const vroot = os.dir(vexe)

const args_string = os.args[1..].join(' ')

const vargs = args_string.all_before('test-all')

const vtest_nocleanup = os.getenv('VTEST_NOCLEANUP').bool()

fn main() {
	mut commands := get_all_commands()
	// summary
	sw := time.new_stopwatch()
	for mut cmd in commands {
		cmd.run()
	}
	spent := sw.elapsed().milliseconds()
	oks := commands.filter(it.ecode == 0)
	fails := commands.filter(it.ecode != 0)
	println('')
	println(term.header_left(term_highlight('Summary of `v test-all`:'), '-'))
	println(term_highlight('Total runtime: $spent ms'))
	for ocmd in oks {
		msg := if ocmd.okmsg != '' { ocmd.okmsg } else { ocmd.line }
		println(term.colorize(term.green, '>          OK: $msg '))
	}
	for fcmd in fails {
		msg := if fcmd.errmsg != '' { fcmd.errmsg } else { fcmd.line }
		println(term.failed('>      Failed:') + ' $msg')
	}
	if fails.len > 0 {
		exit(1)
	}
}

struct Command {
mut:
	line   string
	label  string // when set, the label will be printed *before* cmd.line is executed
	ecode  int
	okmsg  string
	errmsg string
	rmfile string
}

fn get_all_commands() []Command {
	mut res := []Command{}
	res << Command{
		line: '$vexe examples/hello_world.v'
		okmsg: 'V can compile hello world.'
		rmfile: 'examples/hello_world'
	}
	res << Command{
		line: '$vexe -o hhww.c examples/hello_world.v'
		okmsg: 'V can output a .c file, without compiling further.'
		rmfile: 'hhww.c'
	}
	$if linux || macos {
		res << Command{
			line: '$vexe -o - examples/hello_world.v | grep "#define V_COMMIT_HASH" > /dev/null'
			okmsg: 'V prints the generated source code to stdout with `-o -` .'
		}
		res << Command{
			line: '$vexe run examples/v_script.vsh > /dev/null'
			okmsg: 'V can run the .VSH script file examples/v_script.vsh'
		}
		res << Command{
			line: '$vexe -b js -o hw.js examples/hello_world.v'
			okmsg: 'V compiles hello_world.v on the JS backend'
			rmfile: 'hw.js'
		}
		res << Command{
			line: '$vexe -skip-unused -b js -o hw_skip_unused.js examples/hello_world.v'
			okmsg: 'V compiles hello_world.v on the JS backend, with -skip-unused'
			rmfile: 'hw_skip_unused.js'
		}
	}
	res << Command{
		line: '$vexe -o vtmp cmd/v'
		okmsg: 'V can compile itself.'
		rmfile: 'vtmp'
	}
	res << Command{
		line: '$vexe -o vtmp_werror -cstrict cmd/v'
		okmsg: 'V can compile itself with -cstrict.'
		rmfile: 'vtmp_werror'
	}
	res << Command{
		line: '$vexe -o vtmp_autofree -autofree cmd/v'
		okmsg: 'V can compile itself with -autofree.'
		rmfile: 'vtmp_autofree'
	}
	res << Command{
		line: '$vexe -o vtmp_prealloc -prealloc cmd/v'
		okmsg: 'V can compile itself with -prealloc.'
		rmfile: 'vtmp_prealloc'
	}
	res << Command{
		line: '$vexe -o vtmp_unused -skip-unused cmd/v'
		okmsg: 'V can compile itself with -skip-unused.'
		rmfile: 'vtmp_unused'
	}
	$if linux {
		res << Command{
			line: '$vexe -cc gcc -keepc -freestanding -o bel vlib/os/bare/bare_example_linux.v'
			okmsg: 'V can compile with -freestanding on Linux with GCC.'
			rmfile: 'bel'
		}
	}
	res << Command{
		line: '$vexe $vargs -progress test-cleancode'
		okmsg: 'All .v files are invariant when processed with `v fmt`'
	}
	res << Command{
		line: '$vexe $vargs -progress test-fmt'
		okmsg: 'All .v files can be processed with `v fmt`. NB: the result may not always be compilable, but `v fmt` should not crash.'
	}
	res << Command{
		line: '$vexe $vargs -progress test-self'
		okmsg: 'There are no _test.v file regressions.'
	}
	res << Command{
		line: '$vexe $vargs -progress -W build-tools'
		okmsg: 'All tools can be compiled.'
	}
	res << Command{
		line: '$vexe $vargs -progress -W build-examples'
		okmsg: 'All examples can be compiled.'
	}
	res << Command{
		line: '$vexe check-md -hide-warnings .'
		label: 'Check ```v ``` code examples and formatting of .MD files...'
		okmsg: 'All .md files look good.'
	}
	res << Command{
		line: '$vexe install nedpals.args'
		okmsg: '`v install` works.'
	}
	res << Command{
		line: '$vexe -usecache -cg examples/hello_world.v'
		okmsg: '`v -usecache -cg` works.'
		rmfile: 'examples/hello_world'
	}
	// NB: test that a program that depends on thirdparty libraries with its
	// own #flags (tetris depends on gg, which uses sokol) can be compiled
	// with -usecache:
	res << Command{
		line: '$vexe -usecache examples/tetris/tetris.v'
		okmsg: '`v -usecache` works.'
		rmfile: 'examples/tetris/tetris'
	}
	$if macos || linux {
		res << Command{
			line: '$vexe -o v.c cmd/v && cc -Werror -I "$vroot/thirdparty/stdatomic/nix" v.c -lpthread && rm -rf a.out'
			label: 'v.c should be buildable with no warnings...'
			okmsg: 'v.c can be compiled without warnings. This is good :)'
			rmfile: 'v.c'
		}
	}
	return res
}

fn (mut cmd Command) run() {
	// Changing the current directory is needed for some of the compiler tests,
	// vlib/v/tests/local_test.v and vlib/v/tests/repl/repl_test.v
	os.chdir(vroot) or {}
	if cmd.label != '' {
		println(term.header_left(cmd.label, '*'))
	}
	sw := time.new_stopwatch()
	cmd.ecode = os.system(cmd.line)
	spent := sw.elapsed().milliseconds()
	println('> Running: "$cmd.line" took: $spent ms ... ' +
		if cmd.ecode != 0 { term.failed('FAILED') } else { term_highlight('OK') })
	if vtest_nocleanup {
		return
	}
	if cmd.rmfile != '' {
		mut file_existed := rm_existing(cmd.rmfile)
		if os.user_os() == 'windows' {
			file_existed = file_existed || rm_existing(cmd.rmfile + '.exe')
		}
		if !file_existed {
			eprintln('Expected file did not exist: $cmd.rmfile')
			cmd.ecode = 999
		}
	}
}

// try to remove a file, return if it existed before the removal attempt
fn rm_existing(path string) bool {
	existed := os.exists(path)
	os.rm(path) or {}
	return existed
}

fn term_highlight(s string) string {
	return term.colorize(term.yellow, term.colorize(term.bold, s))
}
