Adept - the adaptive JPG Compressor
====================

## Quick Start

soon

## Introduction

When compressing JPEG images, the same compression level is used on the entire image. However, most JPEG images contain homogeneous and heterogeneous areas, which are varyingly well-suited for compression. Compressing heterogeneous areas in JPEGs to reduce filesize causes [compression artefacts](https://en.wikipedia.org/wiki/Compression_artifact) due to the lossy nature of JPEG compression.

This script adaptively alters the compression level for areas within JPEGs to achieve optimal filesize while maintaining decent visual quality. Currently, this script achieves an average 3-5% of reduced filesize compared to standard CLI tools such as jpegoptim while still maintaining good visual quality. This is primarily interesting for the [#WebPerf](https://twitter.com/search?q=%23WebPerf&src=typd) community.

Note that adaptive JPEG compression is already implemented in tools such as Adobe Photoshop and Fireworks. This script brings adaptive JPEG compression to the shell using common console tools already installed on many machines dealing with automated image optimization. The script is save to use as ELA, the [Error Level Analysis Algorithm](http://fotoforensics.com/tutorial-ela.php), does [not flag the images as tainted](http://fotoforensics.com/analysis.php?id=9955933a9ea6774a0e58303db1ac104af8dafd41.107232).

## Image Demos

** GIMP, Save For Web Plugin, Quality 85 - 112,7 kB**
[![Beach GIMp SaveForWeb q85](images/01-01-beach-gimp-saveforweb-q85.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-01-beach-gimp-saveforweb-q85.jpg)

** JPEGOptim --max=85 -t -v --strip-all + lossless JPEGRescan - 110,4 kB**
[![Beach JPEGOptim plus JPEGRescan](images/01-02-beach-jpegoptim-q85-stripall-plus-jpegrescan.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-02-beach-jpegoptim-q85-stripall-plus-jpegrescan.jpg)

** Adept - 107,2 kB**
[![Beach Adept](images/01-03-beach_adept_compress.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-03-beach_adept_compress.jpg)

** Adobe Fireworks + @pornelski's ImageOptim - 106,9 kB**
[![Beach Adept](images/01-04-beach-Adobe-Fireworks-plus-ImageOptim-identical-quality-settings.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-04-beach-Adobe-Fireworks-plus-ImageOptim-identical-quality-settings.jpg)

** JPEGMini - 98,4 kB**
[![Beach Adept](images/01-05-beach-jpegmini.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-05-beach-jpegmini.jpg)

## Known Issues


## Contributors


## Licence