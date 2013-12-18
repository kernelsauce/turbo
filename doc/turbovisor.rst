.. _turbovisor:

************************************
turbovisor -- Application supervisor
************************************

Turbovisor is an application management tool which detects file changes and restart application on the fly.  There are several parameters to control its behavior.

Options
~~~~~~~
\-w, --watch
  specify files or directories to watch.  If directory is given, all its sub-directories will be monitored as well.  By default, turbovisor will monitor current directory.
\-i, --ignore
  specify files or directories to ignore.  If directory is given, all its sub-directories will be ignored as well.  This is uesfull for auto-generated files or temporary files.  By default, no file is ignored.

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

turbovisor myapp/app.lua
  start application, detect any changes in the application

turbovisor myapp/app.lua -w model.lua
  start application, only monitor file model.lua
   
turbovisor myapp/app.lua --watch model.lua main.lua
  start application, only monitor file model.lua and main.lua

turbovisor myapp/app.lua -i static
  start application, detect any changes in the application, except static directory and its sub-directories
  
turbovisor myapp/app.lua --watch static --ignore static/images static/sounds/sound2.mp3
  start application, monitor static directory, but ignore its images sub-directory and sound2.mp3 file
  
