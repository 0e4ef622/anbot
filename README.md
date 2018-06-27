Put your api key in an file named `apikey` in the same directory as the script.

This probably doesn't work on Windows, untested on OSX/macOS.

You also need [`snowman`](https://github.com/KeyboardFire/snowman-lang) somewhere in your `$PATH`.

Run with `perl -CSD derp.pl`

Known Bugs
==========

* Enters infinite loop if there is no internet connection
* Does not respond to commands to print invalid markdown in markdown mode (e.g. `/snowman_md ("O_o"sp`)
