#!/usr/bin/Rscript --no-init-file
# Load the required libraries
library(astro)
library(FITSio)
library(magicaxis)
library(Cairo)
#library(RColorBrewer)

#Spectral <- colorRampPalette(brewer.pal(11,'Spectral'))

# input arguments
inputargs = commandArgs(TRUE)
stub = inputargs[1]
#extension = inputargs[2]
outdir = inputargs[2]

inp=paste(stub,".fits",sep="")

for (extension in 1:16){
#
dat = readFITS(inp,hdu=as.numeric(extension))

# read in keywords
zpkey = "MAGZPT"
zp=as.numeric(dat$hdr[which(dat$hdr=="MAGZPT")+1])
ra = as.numeric(read.fitskey(c("RA"),file=inp,hdu=1))
dec = as.numeric(read.fitskey(c("DEC"),file=inp,hdu=1))
am = (as.numeric(read.fitskey(c("ESO TEL AIRM START"),file=inp,hdu=1)) + as.numeric(read.fitskey(c("ESO TEL AIRM END"),file=inp,hdu=1)))/2
t=as.numeric(dat$hdr[which(dat$hdr=="EXPTIME")+1])
ext=as.numeric(dat$hdr[which(dat$hdr=="EXTINCT")+1])
naxis1=as.numeric(dat$hdr[which(dat$hdr=="NAXIS1")+1])
naxis2=as.numeric(dat$hdr[which(dat$hdr=="NAXIS2")+1])
filter = read.fitskey(c("ESO INS FILT1 NAME"),file=inp,hdu=1)
gain=as.numeric(dat$hdr[which(dat$hdr=="GAINCOR")+1])

#Which filter
if(! filter %in% c("Z","Y","J","H","Ks")) {stop("wrong filter",filter)} 
if(filter=="Z") {abv=0.521}
if(filter=="Y") {abv=0.618}
if(filter=="J") {abv=0.937}
if(filter=="H") {abv=1.384}
if(filter=="Ks") {abv=1.839}
out=paste(outdir,"/",stub,"_",filter,"_",extension,".fits",sep="")
catname=paste(outdir,"/",stub,"_",filter,"_",extension,".cat",sep="")
imag=paste(outdir,"/",stub,"_",filter,"_",extension,".png",sep="")

# AB-magnitude ZP
zp.new = zp - (2.5*log10(1/t)) - (ext*(am-1)) + abv

# pixel modifier factor
pixmod = 10^(-0.4*(zp.new-30))

# modify pixel data
dat$imDat = dat$imDat * pixmod
gain=gain/pixmod

# renorm & update 2
writeFITSim(dat$imDat, file=out, type="single", axDat=dat$axDat, header=dat$header)
write.fitskey("RA", value=ra, file=out,hdu=1)
write.fitskey("DEC", value=dec, file=out,hdu=1)
write.fitskey("MAGZPT", value=30.0, file=out,hdu=1)
write.fitskey("GAINCOR", value=gain, file=out,hdu=1)
write.fitskey("GAIN", value=gain, file=out,hdu=1)
write.fitskey("FILTER", value=filter, file=out,hdu=1)

#setup SExtractor and psfex
sex = "/usr/bin/sex"
psfex = "/usr/bin/psfex"
source("/lscratch/mark/makepsf.r")

# create sex/psfex input files
if(!file.exists("config.psf.sex")){system(paste(sex, "-dd > config.psf.sex"))}
if(!file.exists("param.psf.sex")){cat("NUMBER\nX_IMAGE\nY_IMAGE\nFLUX_RADIUS\nFLAGS\nFLUX_APER(1)\nFLUXERR_APER(1)\nFLUX_MAX\nELONGATION\nVIGNET(50,50)\nBACKGROUND\nSNR_WIN", file="param.psf.sex")}
if(!file.exists("config.psfex")){system(paste(psfex, "-dd > config.psfex"))}


# outputs
sexout = "sexcat.fits"

# Set VIKING pixelsize
pixsize=0.339

# Make the PSF grid.
makePSF(targetFWHM=1,pixelgrid=22,res=pixsize,dofile=T)

#Read in keywords
skylev = read.fitskey(c("SKYLEVEL"),file=out,hdu=1)
skynois = read.fitskey(c("SKYNOISE"),file=out,hdu=1)
hdrseeing = read.fitskey(c("SEEING"),file=out,hdu=1) 
gain = read.fitskey(c("GAINCOR"),file=out,hdu=1)

# run source extractor
sexcmdline = system(paste(sex, out, "-c config.psf.sex -CATALOG_NAME", sexout, "-CATALOG_TYPE FITS_LDAC -PARAMETERS_NAME param.psf.sex -DETECT_MINAREA 9 -DETECT_THRESH 2 -FILTER N -FILTER_NAME PSFmatrix.dat -SATUR_LEVEL 5000000 -SATUR_KEY NOSATURATELEE -MAG_ZEROPOINT", zp, "-GAIN", gain, "-PIXEL_SCALE", pixsize, "-WRITE_XML N 2>&1"), intern=TRUE)

# run PSFEx
psfexcmdline = system(paste(psfex, sexout, "-c config.psfex -PSF_SAMPLING 1.0 -PSFVAR_DEGREES 0 -PSFVAR_NSNAP 1 -SAMPLE_FWHMRANGE 1.0,20.0 -SAMPLE_VARIABILITY 0.75 -SAMPLE_MINSN 5 -SAMPLE_MAXELLIP 0.05 -CHECKPLOT_DEV NULL -CHECKPLOT_TYPE NONE -WRITE_XML N -PSF_SIZE 55,55 2>&1"), intern=TRUE)

# results    
linenum = grep('Saving CHECK-image #1', psfexcmdline) - 1
results = strsplit(psfexcmdline[linenum], " +")
psfaccept=strsplit(results[[1]][2], "/", fixed=T)[[1]][1]
psftotal=strsplit(results[[1]][2], "/", fixed=T)[[1]][2]
psfchi2=results[[1]][4]
psfFWHMpix=results[[1]][5]
psfFWHM=as.numeric(psfFWHMpix)*pixsize
seeing=psfFWHM

# run source extractor second time now with correct seeing
sexcmdline = system(paste(sex, out, "-c config.final.sex -CATALOG_NAME", catname, "-PARAMETERS_NAME param.final.sex -SEEING_FWHM ",seeing," -DETECT_MINAREA 10 -DETECT_THRESH 2 -FILTER Y -FILTER_NAME PSFmatrix.dat -SATUR_LEVEL 5000000 -SATUR_KEY NOSATURATELEE -MAG_ZEROPOINT", zp, "-GAIN", gain, "-PIXEL_SCALE", pixsize, "-WRITE_XML N 2>&1"), intern=TRUE)

linenum=grep('Background',sexcmdline)
sextract = strsplit(sexcmdline[linenum], " +")
back = strsplit(sextract[[1]][3], ":", fixed=T)[[1]][1]
rms = strsplit(sextract[[1]][5], ":", fixed=T)[[1]][1]
thresh = strsplit(sextract[[1]][8], ":", fixed=T)[[1]][1]
offset = (pixsize^2)*10^(-0.4*(22.0-30.0))
if(filter=="Z") {offset = (pixsize^2)*10^(-0.4*(24.0-30.0))}

# generate png image of data frame
CairoPNG(file=imag,width=500,height=500)
par(mar=c(1.1,1.1,1.1,1.1))
magimage(dat$imDat,lo=as.numeric(back)-1.0*offset,hi=(as.numeric(back)+1.0*offset),type="num",scale="log",flip=T,col=rainbow(1e3,start=0,end=2/3))
invisible(dev.off())


origsee=as.numeric(hdrseeing)*pixsize
rachip= as.numeric(read.fitskey(c("CRVAL1"),file=out,hdu=1))
decchip= as.numeric(read.fitskey(c("CRVAL2"),file=out,hdu=1))
raoff= as.numeric(read.fitskey(c("CRPIX1"),file=out,hdu=1))
decoff= as.numeric(read.fitskey(c("CRPIX2"),file=out,hdu=1))
cd1_1=as.numeric(read.fitskey(c("CD1_1"),file=out,hdu=1))
cd1_2=as.numeric(read.fitskey(c("CD1_2"),file=out,hdu=1))
cd2_1=as.numeric(read.fitskey(c("CD2_1"),file=out,hdu=1))
cd2_2=as.numeric(read.fitskey(c("CD2_2"),file=out,hdu=1))

dec=decchip + cd2_1 * (naxis1/2-raoff) + cd2_2 * (naxis2/2-decoff)
ra=rachip + (cd1_1 * (naxis1/2-raoff) + cd1_2 * (naxis2/2-decoff))/cos(decchip/57.29577951)
#rachip=rachip+raoff*pixsize/3600.0
#decchip=decchip+decoff*pixsize/3600.0

# output useful info
cat(inp,out,rachip,decchip,ra,dec,filter,t,am,ext,naxis1,naxis2,zp,pixmod,skylev,skynois,origsee,psfaccept,psftotal,psfFWHM,back,rms,thresh,"\n")
}
