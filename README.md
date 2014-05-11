Adept - the adaptive JPG Compressor
====================

## Quick Start

* Remember: Adept is a **Linux commandline tool**
* Make sure you have [a MSS saliency algorithm binary](http://github.com/technopagan/mss-saliency), [ImageMagick](http://www.imagemagick.org/), [Jpegoptim](https://github.com/tjko/jpegoptim) and [JPEGrescan](https://github.com/kud/jpegrescan) installed & useable.
* Fetch a copy of [adept.sh](https://raw.github.com/technopagan/adept-jpg-compressor/master/adept.sh) and place it somewhere you deem a good place for 3rd party shellscripts, e.g. "/usr/local/bin". Make sure the location is in the PATH of the user(s) who will run adept.sh and ensure that the script is executable (chmod -x).
* Congratulations! You can now run "bash adept.sh /path/to/image.jpg" to compress JPEGs far more successfully.


## Introduction

When compressing JPEG images, the same compression level is used on the entire image. However, most JPEG images contain homogeneous and heterogeneous areas, which are varyingly well-suited for compression. Compressing heterogeneous areas in JPEGs to reduce filesize causes [compression artefacts](https://en.wikipedia.org/wiki/Compression_artifact) due to the lossy nature of JPEG compression.

This script adaptively alters the compression level for areas within JPEGs to achieve optimal filesize while maintaining decent visual quality. This script achieves a significantly reduced filesize compared to standard CLI tools such as jpegoptim while still maintaining good visual quality. This is especially interesting for the [#WebPerf](https://twitter.com/search?q=%23WebPerf&src=typd) and WebDev community.

## Image Demos

### On The Beach

**GIMP, Save For Web Plugin, Quality 85 - 112,7 kB**
[![Beach GIMP SaveForWeb q85](images/01-01-beach-gimp-saveforweb-q85.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-01-beach-gimp-saveforweb-q85.jpg)
GIMP's Save for Web, q85, optimized, Basline & stripped EXIF is the base configuration for all of our test images.

**JPEGOptim --max=85 -t -v --strip-all + lossless JPEGRescan - 110,4 kB**
[![Beach JPEGOptim plus JPEGRescan](images/01-02-beach-jpegoptim-q85-stripall-plus-jpegrescan.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-02-beach-jpegoptim-q85-stripall-plus-jpegrescan.jpg)
Using popular commandline tools for JPG compression, we can achieve a 2.04% smaller filesize with no perceivable loss in quality.

**Adobe Fireworks + @pornelski's ImageOptim - 106,9 kB**
[![Beach Adobe Fireworks and ImageOptim](images/01-04-beach-Adobe-Fireworks-plus-ImageOptim-identical-quality-settings.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-04-beach-Adobe-Fireworks-plus-ImageOptim-identical-quality-settings.jpg)
The commercial Adobe suite, combined with postprocessing by [ImageOptim](http://imageoptim.com/) by [@pornelski](https://twitter.com/pornelski), both set to identical quality settings as the other tools, produces the best result: 5.01% filesize reduction while the horizon's blue gradiant features fewer compression artefacts. Impressive! Sadly, this is not automatable at scale.

**JPEGMini - 98,4 kB**
[![Beach JPEGMini](images/01-05-beach-jpegmini.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-05-beach-jpegmini.jpg)
The big noise of 2011. JPEGMini claimed they reinvented JPEG compression while not breaking the ISO standard. And Yes, the image created by JPEGMini features a whoppin filesize reduction of 12.68%. Sadly, it is also the image with the most visible compression artefacts, also around the key areas of the image. There also is a severe loss of detail on the waves as well as the sand.

**Adept - 91,4 kB**
[![Beach Adept](images/01-03-beach_adept_compress.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-03-beach_adept_compress.jpg)
With Adept, the filesize is reduced by 19%! Slight artefacts can be perceived when zooming in closely on the horizon's blue gradiant because Adept identified the sky as an area of low complexity and thus compressed it more heavily. No artifacts are present at any of the key areas of the image, however (parasol, canvas chair, horizon border, sea-to-sand border etc).

## Contributors

In alphabetical order:

 * [Andy Davies](http://twitter.com/andydavies)
 * [Gregor Fabritius](http://twitter.com/grefab)
 * [Neil Jedrzejewski](http://www.wunderboy.org/about.php)
 * [Alessandro Lenzen](http://twitter.com/adelnorsz)
 * [Claus Meteling](http://www.xing.com/profile/Claus_Meteling)
 * [André Roaldseth](http://twitter.com/androa)
 * [Christian Schäfer](http://twitter.com/derSchepp)
 * [Yoav Weiss](http://twitter.com/yoavweiss)

## Licence

This software is published under the BSD licence 3.0

Copyright (c) 2014, Tobias Baldauf
All rights reserved.

Mail: [kontakt@tobias-baldauf.de](mailto:kontakt@tobias-baldauf.de)
Web: [who.tobias.is](http://who.tobias.is/)
Twitter: [@tbaldauf](http://twitter.com/tbaldauf)

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of the author nor the names of contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
