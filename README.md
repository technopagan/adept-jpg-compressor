Adept - the adaptive JPG Compressor
====================

## Quick Start

soon

## Introduction

When compressing JPEG images, the same compression level is used on the entire image. However, most JPEG images contain homogeneous and heterogeneous areas, which are varyingly well-suited for compression. Compressing heterogeneous areas in JPEGs to reduce filesize causes [compression artefacts](https://en.wikipedia.org/wiki/Compression_artifact) due to the lossy nature of JPEG compression.

This script adaptively alters the compression level for areas within JPEGs to achieve optimal filesize while maintaining decent visual quality. Currently, this script achieves an average 3-5% of reduced filesize compared to standard CLI tools such as jpegoptim while still maintaining good visual quality. This is primarily interesting for the [#WebPerf](https://twitter.com/search?q=%23WebPerf&src=typd) community.

Note that adaptive JPEG compression is already implemented in tools such as Adobe Photoshop and Fireworks. This script brings adaptive JPEG compression to the shell using common console tools already installed on many machines dealing with automated image optimization. The script is save to use as ELA, the [Error Level Analysis Algorithm](http://fotoforensics.com/tutorial-ela.php), does [not flag the images as tainted](http://fotoforensics.com/analysis.php?id=9955933a9ea6774a0e58303db1ac104af8dafd41.107232).

## Image Demos

**GIMP, Save For Web Plugin, Quality 85 - 112,7 kB**
[![Beach GIMp SaveForWeb q85](images/01-01-beach-gimp-saveforweb-q85.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-01-beach-gimp-saveforweb-q85.jpg)
GIMP's Save for Web, q85, optimized, Basline & stripped EXIF is the base configuration for all of our test images.

**JPEGOptim --max=85 -t -v --strip-all + lossless JPEGRescan - 110,4 kB**
[![Beach JPEGOptim plus JPEGRescan](images/01-02-beach-jpegoptim-q85-stripall-plus-jpegrescan.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-02-beach-jpegoptim-q85-stripall-plus-jpegrescan.jpg)
Using popular commandline tools for JPG compression, we can achieve a 2.04% smaller filesize with no perceivable loss in quality.

**Adept - 107,2 kB**
[![Beach Adept](images/01-03-beach_adept_compress.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-03-beach_adept_compress.jpg)
With Adept, the filesize is reduced by 4.88%. Slight artefacts can be perceived when zooming in closely on the horizon's blue gradiant because Adept identified the sky as an area of low complexity and thus compressed it more heavily. No artifacts are present at any of the key areas of the image, however (parasol, canvas chair, horizon border, sea-to-sand border etc). 

**Adobe Fireworks + @pornelski's ImageOptim - 106,9 kB**
[![Beach Adept](images/01-04-beach-Adobe-Fireworks-plus-ImageOptim-identical-quality-settings.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-04-beach-Adobe-Fireworks-plus-ImageOptim-identical-quality-settings.jpg)
The commercial Adobe suite, combined with postprocessing by [ImageOptim](http://imageoptim.com/) by [@pornelski](https://twitter.com/pornelski), both set to identical quality settings as the other tools, produces the best result: 5.01% filesize reduction while the horizon's blue gradiant features fewer compression artefacts. Impressive! Sadly, this is not automatable at scale.

**JPEGMini - 98,4 kB**
[![Beach Adept](images/01-05-beach-jpegmini.jpg)](https://raw.github.com/technopagan/adept-jpg-compressor/master/images/01-05-beach-jpegmini.jpg)
The big noise of 2011. JPEGMini claimed they reinvented JPEG compression while not breaking the ISO standard. And Yes, the image created by JPEGMini features a whoppin filesize reduction of 12.68%. Sadly, it is also the image with the most visible compression artefacts, also around the key areas of the image. There also is a severe loss of detail on the waves as well as the sand.

## Known Issues


## Contributors


## Licence