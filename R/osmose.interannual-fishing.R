# TO-DO: warnings for recycling time series, generic for extension of rate methods
# check deviates are deviates, update the -9999 or equivalent

# Fishing mortality -------------------------------------------------------

getFishingMortality = function(sp, fishing, T, ndt) {

  # validation?
  B = getFishingBaseRate(sp, fishing, T, ndt)
  A = getFishingDeviatesByYear(sp, fishing, T, ndt) 
  S = getFishingDeviatesBySeason(sp, fishing, T, ndt)
  
  F = B*exp(A+S)/ndt # rate by dt!
  
  return(F)
}

# Base rate ---------------------------------------------------------------
# mortality.fishing.rate.method.sp0;"constant","byRegime","linear", "byYear", "byDt"
# # missing/default: nothing, by default hierarchy? error?
# # constant: use rate.sp0
# # byRegime: use rate.byRegime.file.sp0
# # linear  : use rate.slope.sp0
# # byYear  : use rate.byYear.sp0;
# # byDt    : use rate.byDt.sp;
# # mean
# mortality.fishing.rate.sp0;0.5
# mortality.fishing.rate.slope.sp0;0.03 # 3% per year
# mortality.fishing.rate.byRegime.file.sp0;path/to/file
# mortality.fishing.rate.byRegime.sp0;numeric_vector
# mortality.fishing.rate.byRegime.shift.sp0;240
# mortality.fishing.rate.byYear.file.sp0;path/to/file
# mortality.fishing.rate.byYear.sp0;numeric_vector
# mortality.fishing.rate.byDt.file.sp0;path/to/file

getFishingBaseRate = function(sp, fishing, T, ndt) {
  
  method = fishing$rate$method[[sp]]
  useFiles = .getBoolean(fishing$useFiles, FALSE)
  # # constant: use rate.sp0
  # # byRegime: use rate.byRegime.file.sp0
  # # linear  : use rate.slope.sp0
  # # byYear  : use rate.byYear.sp0;
  # # byDt    : use rate.byDt.sp;
  base = switch(method,
                "constant" = getFishingBaseRate.constant(sp, fishing, T, ndt), 
                "byregime" = getFishingBaseRate.byRegime(sp, fishing, T, ndt), 
                "linear"   = getFishingBaseRate.linear(sp, fishing, T, ndt), 
                "byyear"   = getFishingBaseRate.byYear(sp, fishing, T, ndt), 
                "bydt"     = getFishingBaseRate.byDt(sp, fishing, T, ndt))
  
  base = rep(base, length=ndt*T) #???
  
  return(base)
}

getFishingBaseRate.constant = function(sp, fishing, T, ndt) {
  rate = fishing$rate[[sp]]
  if(is.null(rate)) stop(sprintf("No fishing rate provided for %s", sp))
  if(length(rate)>1) stop(sprintf("More than one fishing rate for %s provided.", sp))
  return(rep(rate, T*ndt))
}

getFishingBaseRate.byRegime = function(sp, fishing, T, ndt) {
  
  shifts   = fishing$rate$byRegime$shift[[sp]]
  nRegimes = length(shifts) + 1
  shifts   = shifts[shifts<T*ndt]
  
  useFiles = .getBoolean(fishing$useFiles, FALSE)
  
  if(useFiles) {
    rates = .getFileAsVector(fishing$rate$byRegime$file[[sp]])
    if(is.null(rates)) rates = fishing$rate$byRegime[[sp]]    
  } else {
    rates = fishing$rate$byRegime[[sp]]           
    if(is.null(rates)) rates = .getFileAsVector(fishing$rate$byRegime$file[[sp]])
  }
  
  if(is.null(rates)) stop(sprintf("No fishing rates provided for %s", sp))
  if(length(rates)!=nRegimes) stop(sprintf("You must provided %d fishing rates.", nRegimes))
  
  nRegimes = length(shifts) + 1
  rates  = rates[1:nRegimes]
  
  le = diff(c(0, shifts, T*ndt))
  
  rates = rep.int(rates, le)
  
  return(rates)
}

getFishingBaseRate.linear = function(sp, fishing, T, ndt) {
  
  # mortality.fishing.rate.slope.sp0;0.03 # 3% per year
  rate  = fishing$rate[[sp]]
  slope = fishing$rate$slope[[sp]]
  
  freq = .getFishingFrequency(sp, fishing, ndt)
  
  if(is.null(rate)) stop(sprintf("No fishing rate provided for %s", sp))
  if(length(rate)>1) stop(sprintf("More than one fishing rate for %s provided.", sp))
  if(is.null(slope)) stop(sprintf("No fishing slope provided for %s", sp))
  if(length(slope)>1) stop(sprintf("More than one slope for %s provided.", sp))
  
  time = seq(from=0, by=freq/ndt, length=T*ndt/freq)
  rates = rate + slope*rate*time
  rates = rep(rates, each=freq)
  
  return(rates)
  
}

getFishingBaseRate.byyear = function(sp, fishing, T, ndt) {
  
  useFiles = .getBoolean(fishing$useFiles, FALSE)
  
  if(useFiles) {
    rates = .getFileAsVector(fishing$rate$byyear$file[[sp]])
    if(is.null(rates)) rates = fishing$rate$byyear[[sp]]    
  } else {
    rates = fishing$rate$byyear[[sp]]        
    if(is.null(rates)) rates = .getFileAsVector(fishing$rate$byyear$file[[sp]])
  }

  if(is.null(rates)) stop(sprintf("No fishing rates provided for %s", sp))
  
  freq = .getFishingFrequency(sp, fishing, ndt)
  nPeriods = ndt/freq
  
  if((length(rate)%%nPeriods)!=0) 
    stop(sprintf("You must provide a multiple of %d rates for %s.", nPeriods, sp))
  
  rates = rep(rates, each=freq, length=T*ndt)
  return(rates)
  
}

getFishingBaseRate.bydt = function(sp, fishing, T, ndt) {
  
  useFiles = .getBoolean(fishing$useFiles, FALSE)
  
  if(useFiles) {
    rates = .getFileAsVector(fishing$rate$bydt$file[[sp]])
    if(is.null(rates)) rates = fishing$rate$bydt[[sp]]    
  } else {
    rates = fishing$rate$bydt[[sp]]        
    if(is.null(rates)) rates = .getFileAsVector(fishing$rate$bydt$file[[sp]])
  }
  
  if(is.null(rates)) stop(sprintf("No fishing rates provided for %s", sp))
  
  rates = rep(rates, length=T*ndt)
  return(rates)
  
}

# Annual deviates ---------------------------------------------------------
# mortality.fishing.deviate.byYear.enabled.sp0;true
# # default: false
# # true: add interannual deviates to the mean rate 
# # false: don't add interannual deviates to the mean rate
# mortality.fishing.deviate.byYear.method.sp0;"multiplicative","random.walk"
# mortality.fishing.deviate.byYear.random.sp0;false
# # default: false
# # false: use interannual deviates as time series
# # true: add interannual deviates to the mean rate from distribution
# mortality.fishing.deviate.byYear.random.method.sp0;"distribution","resampling"
# if parameters of the distribution (and distribution) are not specified, used ts
# resampling just reshuffle.
# mortality.fishing.periodsPerYear.sp0;2
# mortality.fishing.deviate.byYear.file.sp0;path/to/file
# mortality.fishing.deviate.byYear.sp0;numeric_vector # length freq*T or freq*T-1 (first is zero)

getFishingDeviatesByYear = function(sp, fishing, T, ndt) {
  
  # rate method
  rateMethod = fishing$rate$method[[sp]]
  if(rateMethod %in% c("byyear", "bydt")) return(rep(0, T*ndt))
  
  isInterannual = .getBoolean(fishing$deviate$byyear$enabled[[sp]], FALSE)
  if(!isInterannual) return(rep(0, T*ndt))
  
  # deviate method
  deviateMethod = fishing$deviate$byyear$method[[sp]]
  if(is.null(deviateMethod)) deviateMethod = "multiplicative" 
  # frequency
  freq = .getFishingFrequency(sp, fishing, ndt)
  ndev = switch(deviateMethod, 
                multiplicative = T*ndt/freq,
                random.walk    = T*ndt/freq - 1)  
  
  useFiles = .getBoolean(fishing$useFiles, FALSE)
  
  if(useFiles) {
    deviates = .getFileAsVector(fishing$deviate$byyear$file[[sp]])
    if(is.null(deviates)) deviates = fishing$deviate$byyear[[sp]]    
  } else {
    deviates = fishing$deviate$byyear[[sp]]        
    if(is.null(deviates)) deviates = .getFileAsVector(fishing$deviate$byyear$file[[sp]])
  }
  
  if(length(deviates)<ndev) 
    stop(sprintf("Not enough annual deviates provided (%d), %d needed.", 
                 length(deviates), ndev))
  
  if(deviateMethod=="random.walk") {
    deviates = cumsum(c(0, deviates))
  }
  
  deviates = rep(deviates, each=freq, length=T*ndt)
  
  return(deviates)
}

# Seasonal deviates -------------------------------------------------------

# mortality.fishing.season.method.sp0;"default", "periodic", "non-periodic"
# # missing: default.
# # default: look for non-periodic then periodic, then uniform
# # periodic: look for periodic, if not create a climatology from non-periodic, then error
# # non-periodic: look for non-periodic, then error
# mortality.fishing.deviate.season.file.sp0;path/to/file
#   mortality.fishing.deviate.season.sp0;numeric_vector # length ndt or >ndt*T
#   mortality.fishing.season.byDt.file.sp0;path/to/file # length ndt or >ndt*T 
#   mortality.fishing.season.distrib.file.sp0;

# getFishingDeviatesBySeason ----------------------------------------------

getFishingDeviatesBySeason = function(sp, fishing, T, ndt) {
  
  rateMethod = fishing$rate$method[[sp]]
  if(rateMethod == "bydt") return(rep(0, T*ndt))
  
  method = fishing$season$method[[sp]]
  if(is.null(method)) method = "default"
  
  useFiles = .getBoolean(fishing$useFiles, FALSE)
  deviates = switch(method,
                    "default"      = getFishingDeviatesBySeason.default(sp, fishing, T, ndt, useFiles),
                    "periodic"     = getFishingDeviatesBySeason.periodic(sp, fishing, T, ndt, useFiles),
                    "non-periodic" = getFishingDeviatesBySeason.nonPeriodic(sp, fishing, T, ndt, useFiles))
  deviates = rep(deviates, length=ndt*T)
  return(deviates)
}

# getFishingDeviatesBySeason.default
getFishingDeviatesBySeason.default = function(sp, fishing, T, ndt, useFiles=FALSE) {
  
  freq = .getFishingFrequency(sp, fishing, ndt)
  
  if(useFiles) {
    deviates = .getFileAsVector(fishing$deviate$season$file[[sp]])
    if(is.null(deviates)) deviates = fishing$deviate$season[[sp]]    
  } else {
    deviates = fishing$deviate$season[[sp]]        
    if(is.null(deviates)) deviates = .getFileAsVector(fishing$deviate$season$file[[sp]])
  }
  
  if(is.null(deviates)) {
    season = .getFileAsVector(fishing$season$byDt$file[[sp]])
    if(is.null(season)) {
      season = .getFileAsVector(fishing$season$distrib$file[[sp]])
    }
    if(is.null(season)) season = rep(1, ndt)
    
    stopifnot(length(season)%%ndt==0)
    
    deviates = .calculateDeviates(x=season, freq, ndt)  
  }
  
  stopifnot(length(deviates)%%ndt==0)
  
  return(as.numeric(deviates))  
  
}


# getFishingDeviatesBySeason.periodic
getFishingDeviatesBySeason.periodic = function(sp, fishing, T, ndt, useFiles=FALSE) {
  
  freq = .getFishingFrequency(sp, fishing, ndt)
  
  if(useFiles) {
    deviates = .getFileAsVector(fishing$deviate$season$file[[sp]])
    if(is.null(deviates)) deviates = fishing$deviate$season[[sp]]    
  } else {
    deviates = fishing$deviate$season[[sp]]        
    if(is.null(deviates)) deviates = .getFileAsVector(fishing$deviate$season$file[[sp]])
  }
  
  if(is.null(deviates)) {
    season = .getFileAsVector(fishing$season$distrib$file[[sp]])
    if(is.null(season)) {
      season = .getFileAsVector(fishing$season$byDt$file[[sp]]) 
      if(is.null(season)) stop(sprintf("No seasonality information for %s", sp))
    }
    stopifnot(length(season)%%ndt==0)
    deviates = .calculateDeviates(x=season, freq, ndt)  
  }
  
  stopifnot(length(deviates)%%ndt==0)
  deviates = calculateSeasonalPattern(x=deviates, ndt=ndt)
  
  return(as.numeric(deviates))  
  
}


# getFishingDeviatesBySeason.nonPeriodic
getFishingDeviatesBySeason.nonPeriodic = function(sp, fishing, T, ndt, useFiles=FALSE) {
  
  freq = .getFishingFrequency(sp, fishing, ndt)
  
  if(useFiles) {
    deviates = .getFileAsVector(fishing$deviate$season$file[[sp]])
    if(is.null(deviates)) deviates = fishing$deviate$season[[sp]]    
  } else {
    deviates = fishing$deviate$season[[sp]]        
    if(is.null(deviates)) deviates = .getFileAsVector(fishing$deviate$season$file[[sp]])
  }
  
  if(is.null(deviates)) {
    season = .getFileAsVector(fishing$season$byDt$file[[sp]]) 
    if(is.null(season)) stop(sprintf("No seasonality information for %s", sp))
    stopifnot(length(season)%%ndt==0)
    deviates = .calculateDeviates(x=season, freq, ndt)  
  }
  
  if(length(deviates)<(ndt*T)) stop("Seasonal information is not appropiate.")
  
  return(as.numeric(deviates))   
  
}