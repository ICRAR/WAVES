
makePSF=function(file='PSFmatrix.dat',dofile=F,res=0.4,targetFWHM=2,pixelgrid=25,norm=T,type='ang',image=F){
#Correct for bad choice of pixel grid
if(pixelgrid %% 2==0){pixelgrid=pixelgrid+1}
#Convert FWHM to sigma
FWHM2sigma=2*sqrt(2*log(2))
targetsigma=targetFWHM/FWHM2sigma
#Make pixel ranges
pixx=(1:pixelgrid)-((pixelgrid+1)/2)
pixy=(1:pixelgrid)-((pixelgrid+1)/2)
#Make angular ranges
angx=pixx*res
angy=pixy*res
#Make angular grid
anggrid=expand.grid(angx,angy)

if(norm=='ang'){norm=2.506628}
if(norm=='pix'){norm=2.506628/res}
#Make 2Dgauss function
gauss2d=function(x=0,y=0,sigma=1,scale=1){
G2D=scale*(1/sqrt(2*pi*sigma^2))*exp(-(x^2+y^2)/(2*sigma^2))
return=G2D
}
#Check integration- I don't think this is required for SExtractor though
if(norm){
int2d=function(funxy,xlim,ylim,...){integrate(Vectorize(function(y){integrate(function(x){funxy(x,y,...)},xlim[1],xlim[2])$value}),ylim[1],ylim[2])$value}
if(type=='ang'){fullint=int2d(gauss2d,c(-Inf,Inf),c(-Inf,Inf),sigma=targetsigma,scale=1)}
if(type=='pix'){fullint=int2d(gauss2d,c(-Inf,Inf),c(-Inf,Inf),sigma=targetsigma/res,scale=1)}
scale=1/fullint
}
#Generate the outputs for our angular grid using the calculated targetsigma and norm (which should be left at 1)
outputgrid=gauss2d(anggrid[,1],anggrid[,2],sigma=targetsigma,scale=scale)
outputmat=matrix(outputgrid,nrow=pixelgrid)
outputlist=list(x=angx,y=angy,z=outputmat)
if(dofile){cat("CONV NORM\n",file=file); write.table(outputlist$z,file=file,row.names=F,col.names=F,append=T)}
if(image){
HWHM=max(as.numeric(outputmat))/2
sigmacuts=gauss2d(0,(1:4)*targetsigma,sigma=targetsigma,scale=scale)
image(outputlist,xlab='x / arsec','ylab=y / arcsec')
contour(outputlist,levels=HWHM,add=T,drawlabels=F,lty=1)
contour(outputlist,levels=sigmacuts,add=T,drawlabels=F,lty=2)
abline(v=c(-targetFWHM,targetFWHM)/2,lty=3)
abline(h=c(-targetFWHM,targetFWHM)/2,lty=3)
int2d=function(funxy,xlim,ylim,...){integrate(Vectorize(function(y){integrate(function(x){funxy(x,y,...)},xlim[1],xlim[2])$value}),ylim[1],ylim[2])$value}
fullint=int2d(gauss2d,c(-Inf,Inf),c(-Inf,Inf),sigma=targetsigma,scale=scale)
legend('topleft',legend=c(paste('FWHM =',targetFWHM),paste('arcsec/pix =',res),paste('Integral =',round(fullint,3))))
}
return=outputlist
}

