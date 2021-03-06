
# Parsing input files -----------------------------------------------------

# guess the type of a vector
.guessType = function(x, keep.att=FALSE) {
  if(!is.character(x)) return(x)
  att = attributes(x)
  x = str_trim(strsplit(tolower(x), split=",")[[1]])
  if(identical(x,"null")) return(NULL) 
  asNum = suppressWarnings(as.numeric(x))
  isNumeric = !all(is.na(asNum))
  x[x=="na"] = NA
  out = if(isNumeric) asNum else x  
  attributes(out) = NULL
  if(keep.att) attributes(out) = att
  return(out) 
}

# get a parameter from a name chain
.getPar = function(x, ..., keep.att=FALSE) {
  chain = tolower(unlist(list(...)))
  if(is.list(x)) x=do.call(.getPar, list(x=x[[chain[1]]], chain[-1]))
  return(.guessType(x, keep.att = keep.att))
}

# get a parameter from a name chain (error if not found)
#' @export
getOsmoseParameter = function(x, ..., keep.att=FALSE) {
  chain = unlist(list(...))
  x = .getPar(x, ..., keep.att=TRUE)
  if(!isTRUE(keep.att)) attributes(x) = NULL
  if(is.null(x)) stop(sprintf("Parameter '%s' not found.", paste(chain, collapse=".")))
  return(x)
}


.getSpecies = function(x)  {
  x = names(x)
  x = grep(pattern = "^sp[0-9]*$", x = x, value=TRUE)
  return(x)
}

.getBoolean = function(x, default=NULL) {
  if(is.null(x)) return(default)
  if(length(x)>1) stop("More than one value provided.")
  if(is.logical(x)) return(x)
  x = tolower(x)
  if(x=="true") return(TRUE)
  if(x=="false") return(FALSE)
  stop(sprintf("Invalid input, %s is not boolean.", x))
}

.readInputCsv = function(file) {
  sep = .guessSeparator(readLines(file, n=1))
  out = read.csv(file, sep=sep, row.names=1)
}

.getFileAsVector = function(file) {
  if(is.null(file)) return(NULL)
  path = attr(file, which="path")
  if(!is.null(path)) file=file.path(path, file)
  if(!file.exists(file)) stop(sprintf("File %s not found", file))
  out = .readInputCsv(file=file)
  out = as.numeric(as.matrix(out))
  return(out)
}


# Parsing OSMOSE outputs --------------------------------------------------

.bySpecies = function(files, sep=c("_", "-")) {
  out = NULL
  if(length(files)>0) {
    sp  = sapply(sapply(files, FUN=.strsplit2v, sep[1],
                        USE.NAMES=FALSE)[2,], FUN=.strsplit2v, sep[2],
                 USE.NAMES=FALSE)[2,]
    out = as.list(tapply(files, INDEX=sp, FUN=identity))
  }
  # change names for all species
  return(out)
}

.strsplit2v = function(...) {
  out = matrix(unlist(strsplit(...)), ncol=1)
  names(out) = NULL
  return(out)
}

.getModelName = function(path) {
    strsplit(dir(path=path, pattern="_biomass_")[1],"_")[[1]][1]
  }

.readOsmoseCsv = function(file, sep=",", skip=1, row.names=1, 
                          na.strings=c("NA", "NaN"), rm=1, ...) {
  out = read.csv(file=file, sep=sep, skip=skip, 
                 row.names=row.names, na.strings=na.strings, ...)
  #   mat = as.matrix(out)
  #   out[is.na(mat) & !is.nan(mat)] = Inf
  #   out[is.na(mat) & is.nan(mat)] = NA
  return(out)
}


.readMortalityCsv = function(file, sep=",", skip=1, row.names=1, 
                             na.strings=c("NA", "NaN"), rm=1, ...) {
  
  x = readLines(file)
  .subSep = function(x) gsub(";", ",", x)
  
  x = lapply(x, .subSep)
  legend = x[[1]]
  headers = x[2:3]
  x = x[-c(1:3)]
  x = paste(x, collapse="\n")
  x = read.csv(text=x, header=FALSE, na.strings=na.strings)
  times = x[,1]
  x = as.matrix(x[, -c(1,17)])
  x = array(as.numeric(x), dim=c(nrow(x), 3, 5))
  rownames(x) = round(times, 2)
  dimnames(x)[[3]] = c("pred", "starv", "other", "fishing", "out")
  
  return(x)
}

.errorReadingOutputs = function(e) {
  warning(e)
  return(invisible(NULL))
}

.warningReadingOutputs = function(type) {
  e = sprintf("File type '%s' is not recognized by Osmose2R", type)
  warning(e)
  return(invisible(NULL))
}


.readFilesList = function(files, path, type, ...) {
  output = tryCatch(
    switch(type,
           abundance       =  .read_1D(files=files, path=path, ...),
           biomass         =  .read_1D(files=files, path=path, ...),
           yield           =  .read_1D(files=files, path=path, ...),
           yieldN          =  .read_1D(files=files, path=path, ...),
           meanTL          =  .read_1D(files=files, path=path, ...),
           meanTLCatch     =  .read_1D(files=files, path=path, ...),
           meanSize        =  .read_1D(files=files, path=path, ...),
           meanSizeCatch   =  .read_1D(files=files, path=path, ...),
           biomassPredPreyIni =  .read_1D(files=files, path=path, ...),
           predatorPressure          = .read_2D(files=files, path=path, ...),
           dietMatrix                = .read_2D(files=files, path=path, ...),
           AgeSpectrumSpeciesB       = .read_2D(files=files, path=path, ...),
           AgeSpectrumSpeciesN       = .read_2D(files=files, path=path, ...),
           AgeSpectrumSpeciesYield   = .read_2D(files=files, path=path, ...),
           AgeSpectrumSpeciesYieldN  = .read_2D(files=files, path=path, ...),
           SizeSpectrum              = .read_2D(files=files, path=path, ...),
           SizeSpectrumSpeciesB      = .read_2D(files=files, path=path, ...),
           SizeSpectrumSpeciesN      = .read_2D(files=files, path=path, ...),
           SizeSpectrumSpeciesYield  = .read_2D(files=files, path=path, ...),
           SizeSpectrumSpeciesYieldN = .read_2D(files=files, path=path, ...),
           mortalityRate             = .read_MortStage(files=files, path=path, ...),
           
           # osmose 3r1
           #            mortalityRateDistribByAge = .read_MortStagebyAgeorSize(files=files, path=path, ...),
           #            mortalityRateDistribBySize = .read_MortStagebyAgeorSize(files=files, path=path, ...),
           mortalityRateDistribByAge      = .read_2D(files=files, path=path, ...),
           mortalityRateDistribBySize     = .read_2D(files=files, path=path, ...),
           abundanceDistribBySize         = .read_2D(files=files, path=path, ...),
           biomasDistribBySize            = .read_2D(files=files, path=path, ...),
           naturalMortalityDistribBySize  = .read_2D(files=files, path=path, ...),
           naturalMortalityNDistribBySize = .read_2D(files=files, path=path, ...),
           yieldDistribBySize             = .read_2D(files=files, path=path, ...),
           yieldNDistribBySize            = .read_2D(files=files, path=path, ...),
           abundanceDistribByAge          = .read_2D(files=files, path=path, ...),
           biomasDistribByAge             = .read_2D(files=files, path=path, ...),
           meanSizeDistribByAge           = .read_2D(files=files, path=path, ...),
           naturalMortalityDistribByAge   = .read_2D(files=files, path=path, ...),
           naturalMortalityNDistribByAge  = .read_2D(files=files, path=path, ...),
           yieldDistribByAge              = .read_2D(files=files, path=path, ...),
           yieldNDistribByAge             = .read_2D(files=files, path=path, ...),
           biomasDistribByTL              = .read_2D(files=files, path=path, ...),
           #            dietMatrixbyAge                = .read_2D_ByAgeorSize(files=files, path=path, ...),
           #            dietMatrixbySize               = .read_2D_ByAgeorSize(files=files, path=path, ...),
           dietMatrixbyAge                = .read_2D(files=files, path=path, ...),
           dietMatrixbySize               = .read_2D(files=files, path=path, ...),
           meanTLDistribByAge             = .read_2D(files=files, path=path, ...),
           meanTLDistribBySize            = .read_2D(files=files, path=path, ...),
           predatorPressureDistribByAge   = .read_2D(files=files, path=path, ...),
           predatorPressureDistribBySize  = .read_2D(files=files, path=path, ...),
           .warningReadingOutputs(type)), 
    error = .errorReadingOutputs)
  
  return(output)
}

.read_1D = function(files, path, ...) {
  # TO_DO: change for the unified approach! species as list
  if(length(files)!=0) {
    x = .readOsmoseCsv(file.path(path, files[1]), ...)
    species = names(x)
    times   = rownames(x)
    
    output = array(dim=c(dim(x),length(files)))
    output[,,1] = as.matrix(x)
    if(length(files)>1) {
      for(i in seq_along(files[-1])) {
        x = .readOsmoseCsv(file.path(path, files[i+1]), ...)
        output[,,i+1]= as.matrix(x)
      }
    }
    rownames(output) = times
    colnames(output) = species
  } else {
    output = NULL
  }
  
  return(output)
}

.read_2D = function(files, path, ...) {
  
  if(length(files)!=0) {
    
    x = .readOsmoseCsv(file.path(path, files[1]), row.names=NULL, ...)
    
    rows    = unique(x[,1])
    cols    = unique(x[,2])
    slices  = names(x)[-(1:2)]
    
    x = .reshapeOsmoseTable(x)
    
    out = array(dim = c(dim(x), length(files)))
    
    out[, , , 1] = x
    
    if(length(files)>1) {
      for(i in seq_along(files[-1])) {
        x = .readOsmoseCsv(file.path(path, files[i+1]), row.names=NULL, ...)
        x = .reshapeOsmoseTable(x)
        out[, , , i+1]= x
      }
    }
    
    out = aperm(out, c(1,2,4,3))
    
    rownames(out) = rows
    colnames(out) = cols
    
    nsp = dim(out)[4]
    
    output=list()
    
    for(i in seq_len(nsp)) {
      y = out[, , , i, drop=FALSE]
      dnames = dimnames(y)[1:3]
      dim(y) = dim(y)[-length(dim(y))]
      dimnames(y) = dnames
      output[[i]] = drop(y)
    }
    
    names(output) = slices
    
  } else {
    output = NULL
  }
  
  return(output)
}

.read_MortStage = function(files, path, ...) {
  
  if(length(files)!=0) {
    
    x = .readMortalityCsv(file.path(path, files[1]), row.names=NULL, ...)
    
    rows = row.names(x)
    cols = c("pred", "starv", "other", "fishing", "out")
    
    out = array(dim = c(dim(x), length(files)))
    
    out[, , , 1] = x
    
    if(length(files)>1) {
      for(i in seq_along(files[-1])) {
        x = .readMortalityCsv(file.path(path, files[i+1]), row.names=NULL, ...)
        out[, , , i+1]= x
      }
    }
    
    rownames(out) = rows
    dimnames(out)[[3]] = cols
    
    output=list()
    
    output$eggs      = out[, 1, ,]
    output$juveniles = out[, 2, ,]
    output$adults    = out[, 3, ,]
    
  } else {
    output = NULL
  }
  
  return(output)
}


.reshapeOsmoseTable = function(x) {
  
  rows    = unique(x[,1])
  cols    = unique(x[,2])
  slices  = names(x)[-(1:2)]
  
  x       = as.matrix(x[,-(1:2)])
  dim(x)  = c(length(cols), length(rows), length(slices))
  x       = aperm(x, c(2,1,3))
  
  dimnames(x) = list(rows, cols, slices)
  
  return(x)
}

.rewriteOutputs = function(path) {
  dir.create(file.path(path, "osmose2R"))
  # not finished
}

.countOnes = function(files, ...) {
  
  out = numeric(length(files))
  
  for(i in seq_along(files)) {
    
    x = read.csv(files[i], header=FALSE, ...)
    out[i] = sum(x>0, na.rm=TRUE)
    
  }
  
  out = c(min=min(out), mean=mean(out), 
          median=median(out), max=max(out))
  return(out)
  
}


.removeZeros = function(object) {
  remove = apply(object, 2, function(x) all(x==0))
  object = object[ , !remove, ]
  return(object)
}


.getmfrow = function(n) {
  m1 = floor(sqrt(n))
  m2 = ceiling(n/m1)
  out = rev(sort(c(m1, m2)))
  return(out)
}




