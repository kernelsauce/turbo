.. _apiref:

************************
Turbo.lua API Versioning
************************

.. highlight:: lua

Preliminaries
=============
All modules are required in turbo.lua, so it's enough to

::

   local turbo = require('turbo')

All functionality is placed in the "turbo" namespace.

Module Version
==============
The Turbo Web version is of the form *A.B.C*, where *A* is the
major version, *B* is the minor version, and *C* is the micro version.
If the micro version is zero, it's omitted from the version string.

When a new release only fixes bugs and doesn't add new features or
functionality, the micro version is incremented. When new features are
added in a backwards compatible way, the minor version is incremented
and the micro version is set to zero. When there are backwards
incompatible changes, the major version is incremented and others are
set to zero.

The following constants specify the current version of the module:

``turbo.MAJOR_VERSION``, ``turbo.MINOR_VERSION``, ``turbo.MICRO_VERSION``
  Numbers specifiying the major, minor and micro versions respectively.

``turbo.VERSION``
  A string representation of the current version, e.g ``"1.0.0"`` or ``"1.1.0"``.

``turbo.VERSION_HEX``
  A 3-byte hexadecimal representation of the version, e.g.
  ``0x010201`` for version 1.2.1 and ``0x010300`` for version 1.3.
