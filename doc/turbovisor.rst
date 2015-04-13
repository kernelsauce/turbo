.. _turbovisor:

************************************
turbovisor -- Application supervisor
************************************

Turbovisor is an application management tool which detects file changes and restart application on the fly.  There are several parameters to control its behavior.

Options
~~~~~~~
\-w, --watch
  Specify files or directories to watch.  If directory is given, all its sub-directories will be monitored as well.  By default, turbovisor will monitor current directory.
\-i, --ignore
  Specify files or directories to ignore.  If directory is given, all its sub-directories will be ignored as well.  This is uesfull for auto-generated files or temporary files.  By default, no file is ignored.

Examples
~~~~~~~~
Suppose we have the following directory tree, and turbovisor is invoked in the app's root directory

::

  MyApp
  |-- doc
  |   |-- doc1.rst
  |   |-- doc2.rst
  |-- main.lua
  |-- model.lua
  |-- templates
  |   |-- view.lua
  |-- static
  |   |-- files
  |       |-- file1
  |       |-- file2
  |   |-- images
  |       |-- image1.jpg
  |       |-- image2.jpg
  |   |-- sounds
  |       |-- sound1.mp3
  |       |-- sound2.mp3
  |-- test.lua


turbovisor main.lua
  start application, detect any changes in the application

turbovisor main.lua -w model.lua
  start application, only monitor file model.lua

turbovisor main.lua --watch model.lua main.lua
  start application, only monitor file model.lua and main.lua

turbovisor main.lua -i static
  start application, detect any changes in the application, except static directory and its sub-directories

turbovisor main.lua --watch static --ignore static/images static/sounds/sound2.mp3
  start application, monitor static directory, but ignore its images sub-directory and sound2.mp3 file

