
getmfrow = function(n) .getmfrow(n=n)


makeTransparent = function(..., alpha=0.5) {
  
  if(alpha<0 | alpha>1) stop("alpha must be between 0 and 1")
  
  alpha = floor(255*alpha)  
  newColor = col2rgb(col=unlist(list(...)), alpha=FALSE)
  
  .makeTransparent = function(col, alpha) {
    rgb(red=col[1], green=col[2], blue=col[3], alpha=alpha, maxColorValue=255)
  }
  
  newColor = apply(newColor, 2, .makeTransparent, alpha=alpha)
  
  return(newColor)
  
}


readOsmoseFiles = function(path, type, bySpecies=FALSE, ...) {
  
  xclass = paste("osmose", type, sep=".")
  
  
  allFiles = dir(path=path, recursive=TRUE, include.dirs=FALSE)
  csvFiles = allFiles[grepl(".csv", allFiles)]
  
  if(!isTRUE(bySpecies)) {
    
    type_  = paste0(type, "_")
    files  = csvFiles[grepl(type_, csvFiles)]
    output = .readFilesList(files=files, path=path, type=type, ...)
    
  } else {
    
    type_  = paste0(type, "-")
    files  = csvFiles[grepl(type_, csvFiles)]
    files  = .bySpecies(files=files)
    output = lapply(files, FUN=.readFilesList, path=path, type=type, ...)
    
  }
  
  if(!is.null(output)) class(output) = c(xclass, class(output))
  
  return(output)
  
}


getSizeSpectrum = function(file, sep=",") {
  # use readOsmoseCsv
  sizeSpectrum = read.table(file, sep=sep, dec=".", skip=1,
                            header=TRUE)
  nsp = ncol(sizeSpectrum) - 2
  times = unique(sizeSpectrum$Time)
  lengths = unique(sizeSpectrum$Size)
  
  out = array(dim = c(length(times), length(lengths), nsp))
  
  for(t in seq_along(times)) {
    out[t,,]  = as.matrix(sizeSpectrum[sizeSpectrum$Time==times[t],-(1:2)])
  }
  colnames(out) = lengths
  rownames(out) = round(times,3)
  dimnames(out)[[3]] = paste0("sp.", seq(nsp)-1)
  return(out)
}



getMortality = function(x, stage="adults", type="total") {
  .calcMort = function(x) {
    x = as.data.frame(x)
    x$natural = x$pred + x$starv + x$other + x$out
    x$total = x$natural + x$fishing
    return(x)
  }
  .getZ = function(x, stage, type) {
    x = x[[stage]]
    x = apply(x, 1:2, mean, na.rm=TRUE)
    x = .calcMort(x)
    x = x[, type]
    return(x)
  }
  
  out = sapply(x, .getZ, stage=stage, type=type)
  return(out)
}


getAverageMortality = function(x, stage="adults", freq=12) {
  
  .getZ = function(x, stage) {
    x = x[[stage]]
    x = apply(x, 1:2, mean, na.rm=TRUE)
    x = freq*colMeans(x, na.rm=TRUE)
    return(x)
  }
  
  out = sapply(x, .getZ, stage=stage)
  return(out)
}

getMortalityDeviation = function(x, stage, type, pars=NULL) {
  x     = getMortality(x=x, stage=stage, type=type)
  if(!is.null(pars)) {
    proxy = pars$dt.save*pars$M.proxy/pars$dt    
  } else {
    proxy = colMeans(x)
  }
  out   = t(apply(x, 1, "-", proxy))
  return(out)
}



# osmose2R for specific versions ------------------------------------------

osmose2R.v3r0 = function(path=NULL, species.names=NULL, ...) {
  
  # General  
  pop = list(
    biomass    = readOsmoseFiles(path=path, type="biomass"),
    abundance  = readOsmoseFiles(path=path, type="abundance"),
    yield      = readOsmoseFiles(path=path, type="yield"),
    catch      = readOsmoseFiles(path=path, type="yieldN"),
    mortality  = readOsmoseFiles(path=path, type="mortalityRate", bySpecies=TRUE)
  )
  
  # Trophic
  Trophic = list(
    meanTL      = readOsmoseFiles(path=path, type="meanTL"),
    meanTLCatch = readOsmoseFiles(path=path, type="meanTLCatch"),
    predatorPressure = readOsmoseFiles(path=path, type="predatorPressure"),
    predPreyIni = readOsmoseFiles(path=path, type="biomassPredPreyIni")
  )
  
  # Size indicators
  Size = list(
    meanSize      = readOsmoseFiles(path=path, type="meanSize"),
    meanSizeCatch = readOsmoseFiles(path=path, type="meanSizeCatch"),
    SizeSpectrum  = readOsmoseFiles(path=path, type="SizeSpectrum")$Abundance,
    SizeSpectrumN = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesN"),
    SizeSpectrumB = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesB"),
    SizeSpectrumC = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesYield"),
    SizeSpectrumY = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesYieldN")
  )
  
  # Age indicators
  Age = list(
    AgeSpectrumN = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesN"),
    AgeSpectrumB = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesB"),
    AgeSpectrumC = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesYield"),
    AgeSpectrumY = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesYieldN")
  )
  
  model = list(
    version  = "3.0b",
    model    = .getModelName(path=path),
    simus    = dim(pop$biomass)[3],
    times    = as.numeric(row.names(pop$biomass)),
    T        = nrow(pop$biomass),
    start    = as.numeric(row.names(pop$biomass))[1],
    nsp      = ncol(pop$biomass),
    lspecies = if(!is.null(species.names)) species.names else colnames(pop$biomass)
  )
  
  
  output = list(model   = model,
                species = colnames(pop$biomass),
                global  = pop,
                trophic = Trophic,
                size    = Size,
                age     = Age
  )
  
  return(output)
  
}

osmose2R.v3r1 = function(path=NULL, species.names=NULL, ...) {
  
  # General  
  pop = list(
    biomass    = readOsmoseFiles(path=path, type="biomass"),
    abundance  = readOsmoseFiles(path=path, type="abundance"),
    yield      = readOsmoseFiles(path=path, type="yield"),
    catch      = readOsmoseFiles(path=path, type="yieldN"),
    mortality  = readOsmoseFiles(path=path, type="mortalityRate", bySpecies=TRUE)
  )
  
  # Trophic
  Trophic = list(
    dietMatrix  = readOsmoseFiles(path=path, type="dietMatrix"),
    meanTL      = readOsmoseFiles(path=path, type="meanTL"),
    meanTLCatch = readOsmoseFiles(path=path, type="meanTLCatch"),
    predatorPressure = readOsmoseFiles(path=path, type="predatorPressure"),
    predPreyIni = readOsmoseFiles(path=path, type="biomassPredPreyIni"),
    TLDistrib   = readOsmoseFiles(path=path, type="TLDistrib")
  )
  
  # Size indicators
  Size = list(
    meanSize      = readOsmoseFiles(path=path, type="meanSize"),
    meanSizeCatch = readOsmoseFiles(path=path, type="meanSizeCatch"),
    SizeSpectrum  = readOsmoseFiles(path=path, type="SizeSpectrum")$Abundance,
    SizeSpectrumN = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesN"),
    SizeSpectrumB = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesB"),
    SizeSpectrumC = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesYield"),
    SizeSpectrumY = readOsmoseFiles(path=path, type="SizeSpectrumSpeciesYieldN")
  )
  
  # Age indicators
  Age = list(
    AgeSpectrumN = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesN"),
    AgeSpectrumB = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesB"),
    AgeSpectrumC = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesYield"),
    AgeSpectrumY = readOsmoseFiles(path=path, type="AgeSpectrumSpeciesYieldN")
  )
  
  model = list(
    version  = "3u1",
    model    = .getModelName(path=path),
    simus    = dim(pop$biomass)[3],
    times    = as.numeric(row.names(pop$biomass)),
    T        = nrow(pop$biomass),
    start    = as.numeric(row.names(pop$biomass))[1],
    nsp      = ncol(pop$biomass),
    lspecies = if(!is.null(species.names)) species.names else colnames(pop$biomass)
  )
  
  
  output = list(model   = model,
                species = colnames(pop$biomass),
                global  = pop,
                trophic = Trophic,
                size    = Size,
                age     = Age
  )
  
  return(output)
  
}

osmose2R.v3r2 = function (path = NULL, species.names = NULL, ...) {
  
  
  pop = list(biomass = readOsmoseFiles(path = path, type = "biomass"), 
             abundance = readOsmoseFiles(path = path, type = "abundance"), 
             yield = readOsmoseFiles(path = path, type = "yield"), 
             yieldN = readOsmoseFiles(path = path, type = "yieldN"),
             mortality = readOsmoseFiles(path = path, type = "mortalityRate", bySpecies = TRUE))
  
  Trophic = list(meanTL = readOsmoseFiles(path = path, type = "meanTL"), 
                 meanTLCatch = readOsmoseFiles(path = path, type = "meanTLCatch"),
                 biomassByTL = readOsmoseFiles(path = path, type = "biomasDistribByTL"),
                 predatorPressure = readOsmoseFiles(path = path, type = "predatorPressure"), 
                 predPreyIni = readOsmoseFiles(path = path, type = "biomassPredPreyIni"),
                 dietMatrix = readOsmoseFiles(path = path, type = "dietMatrix"))
  
  Size = list(meanSize = readOsmoseFiles(path = path, type = "meanSize"),            
              meanSizeCatch = readOsmoseFiles(path = path, type = "meanSizeCatch"),
              SizeSpectrum  = readOsmoseFiles(path=path, type="SizeSpectrum")$Abundance,
              abundanceBySize = readOsmoseFiles(path = path, type = "abundanceDistribBySize"),
              biomassBySize = readOsmoseFiles(path = path, type = "biomasDistribBySize"),
              yieldBySize = readOsmoseFiles(path = path, type = "yieldDistribBySize"),
              yieldNBySize = readOsmoseFiles(path = path, type = "yieldNDistribBySize"),
              meanTLBySize = readOsmoseFiles(path = path, type = "meanTLDistribBySize"),
              mortalityBySize = readOsmoseFiles(path = path, type = "mortalityRateDistribBySize", bySpecies = TRUE),
              dietMatrixBySize = readOsmoseFiles(path = path, type = "dietMatrixbySize", bySpecies = TRUE),
              predatorPressureBySize = readOsmoseFiles(path = path, type = "predatorPressureDistribBySize", bySpecies = TRUE))
  
  
  Age = list(abundanceByAge = readOsmoseFiles(path = path, type = "abundanceDistribByAge"),
             biomassByAge = readOsmoseFiles(path = path, type = "biomasDistribByAge"),
             yieldByAge = readOsmoseFiles(path = path, type = "yieldDistribByAge"),
             yieldNByAge = readOsmoseFiles(path = path, type = "yieldNDistribByAge"),
             meanSizeByAge = readOsmoseFiles(path = path, type = "meanSizeDistribByAge"),
             meanTLByAge = readOsmoseFiles(path = path, type = "meanTLDistribByAge"),
             mortalityByAge = readOsmoseFiles(path = path, type = "mortalityRateDistribByAge", bySpecies = TRUE),
             dietMatrixByAge = readOsmoseFiles(path = path, type = "dietMatrixbyAge", bySpecies = TRUE),
             predatorPressureByAge = readOsmoseFiles(path = path, type = "predatorPressureDistribByAge", bySpecies = TRUE))
  
  
  model = list(version = "3u2",
               model = .getModelName(path = path), 
               simus = dim(pop$biomass)[3], 
               times = as.numeric(row.names(pop$biomass)), 
               T = nrow(pop$biomass), 
               start = as.numeric(row.names(pop$biomass))[1], 
               nsp = ncol(pop$biomass), 
               lspecies = if (!is.null(species.names)) species.names else colnames(pop$biomass))
  
  output = list(model = model, species = colnames(pop$biomass), 
                global = pop, trophic = Trophic, size = Size, age = Age)
  
  
  return(output)
}

