##=======================================================================================
## Data conversion functions in R
##
## BSD 3-Clause License
##
## Copyright (c) 2015, Anton Antonov
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
## * Redistributions of source code must retain the above copyright notice, this
## list of conditions and the following disclaimer.
##
## * Redistributions in binary form must reproduce the above copyright notice,
## this list of conditions and the following disclaimer in the documentation
## and/or other materials provided with the distribution.
##
## * Neither the name of the copyright holder nor the names of its
## contributors may be used to endorse or promote products derived from
## this software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
## DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
## FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
## DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
##          SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
## CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
## OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
## OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
## 
## Written by Anton Antonov, 
## antononcube@gmail.com,
## Windermere, Florida, USA.
##
##=======================================================================================
## Start date: April 2014
##
## This file has R functions that help the ingesting of data in R.
## Some of the functions address problematic reading of TSV / CSV files.
## Some are for field paritioning.
## Some are for conversion to sparse matrices.
##
##=======================================================================================
##
## This file is included in ERTMon-R R directory in order to simplify ERTMon-R's package 
## installation and function dependencies load.
##
## The most recent version of this file can be found in:
##     https://github.com/antononcube/MathematicaForPrediction/blob/master/R/DataConversionFunctions.R
##
##=======================================================================================

# Load libraries
library(plyr)
library(stringr)
library(reshape2)
library(Matrix)
library(lubridate)
library(dplyr)

#' Split column of tags.
#' @description Partition combined columns
#' @param dataColumn data vector
#' @param numberOfSplits number of strings into which is field is splitted
#' @param emptyStringReplacement with what value empty strings are replaced
#' @export
SplitColumnOfTags <- function( dataColumn, numberOfSplits, sep = ",", emptyStringReplacement = "null"  ) {
  spCol <- str_split_fixed( dataColumn, sep, numberOfSplits )
  spCol[ spCol == "" ] <- emptyStringReplacement
  #spCol[ spCol == "null"] <- NA
  ##spCol <- apply( spCol, c(1,2), str_trim)
  spCol <- apply( spCol, c(2), str_trim)
  spCol
}

#' Tag baskets matrix into item tag matrix
#' @description Tag table (an R-matrix) into binary incedence sparse matrix
#' @param itemTagMat item-tag table
#' @export
TagBasketsMatrixIntoItemTagMatrix <- function( itemTagMat ) {
  # Convert to long form
  itRows <-
    adply(itemTagMat, c(1), function(x) {
      row <- x[2:length(x)]
      row <- row[ !is.na(row) ]
      ldply( row, function(y) c(x[1], y))
    })
  itRows$V2[ itRows$V2 == "" ] <- "null"
  # Convert long form to sparse martix
  SMRCreateItemTagMatrix( itRows, "V1", "V2" )
}

#' File columns ingestion.
#' @description Given a file name reads the data into column data frame
#' @param fname filename assumed with suffix "TSV"
#' @param sep separator
#' @param header a logical value indicating whether the file contains the names of 
#' the variables as its first line
#' @export
FileColumnsIngest <- function( fname, sep="\t", expectedColumns=3, header=TRUE, apply.iconv = TRUE ) {
  con <- file(fname, "rb")
  if ( apply.iconv ) {
    rawContent <- iconv( readLines(con) )
  } else {
    rawContent <- readLines(con)
  }
  close(con)  # close the connection to the file, to keep things tidy

  # for each line in rawContent
  # count the number of delims and compare that number to expectedColumns
  indexToOffenders <-
    laply(rawContent, function(x) {
      length(gregexpr(sep, x)[[1]]) != (expectedColumns-1)
    })

  # triplets <- read.csv2(rawContent[-indxToOffenders], header=TRUE, sep=cdelim)
  if ( sum(indexToOffenders) > 0 ) {
    rawContent <- rawContent[-indexToOffenders]
  }

  triplets <-
    ldply( rawContent, function(x) {
      if ( is.null(x) ) {
        NULL
      } else {
        res <- strsplit(x, sep )
        if ( is.null(res) || length(res) == 0 ) { NULL } else { res[[1]] }
      }
    } )

  if ( header ) {
    names(triplets) <- triplets[1,]
    triplets <- triplets[-1,]
  }
  triplets
}

#' File triplets ingestion.
#' @description Given a file name reads the data into three-column data frame, removes rows with NA and "null"
#' @param fname file name
#' @param sep separator
#' @export
FileTripletsIngest <- function( fname, sep="\t" ) {
  lines <- FileColumnsIngest(fname, sep, 3)
  lines[,3] <- as.numeric( lines[,3] )
  lines[,2] <- as.character( lines[,2] )
  lines[,1] <- as.character( lines[,1] )
  lines[ is.na( lines[,3]), 3] <- 0
  lines <- lines[ nchar( lines[,2] ) > 0,  ]
  lines <- lines[ nchar( lines[,1] ) > 0,  ]
  lines <- lines[ complete.cases(lines), ]
}

#' File triplets.
#' @description Turns the triplet records of a file into a sparse matrix
#' @param fname file name
#' @param sep field separator
#' @param propertiesToStrings should all properties be turned into strings
#' @export
FileTriplets <-  function( fname, sep="\t", propertiesToStrings=TRUE ) {
  df <- FileTripletsIngest( fname, sep )
  TripletsToSparseArray( df )
}

#' Combine two triplets files.
#' @description Combining the triplets of two files into a sparse matrix
#' @param fname1 name of the first file
#' @param fname2 name of the second file
#' @param sep field separator
#' @param propertiesToStrings should the properties be converted into stings
#' @export
TwoFilesTriplets <- function( fname1, fname2, sep="\t", propertiesToStrings=TRUE ) {
  df1 <- FileTripletsIngest( fname1, sep )
  df2 <- FileTripletsIngest( fname2, sep )
  TripletsToSparseArray( rbind(df1, df2) )
}

#' Make a sparse array/matrix from triplets.
#' @description Turns a data frame of three columns (triplets) into a sparse matrix
#' @param triplets a data frame with three columns
#' @export
TripletsToSparseMatrix <-  function( triplets ) {
  itemIDs <- unique( triplets[,1] )
  propertyIDs <- unique( triplets[,2] )
  itemIDToIndex <- 1:length(itemIDs)
  names(itemIDToIndex) <- itemIDs
  propertyIDToIndex <- 1:length(propertyIDs)
  names(propertyIDToIndex) <- propertyIDs
  smat <- sparseMatrix( i=itemIDToIndex[ triplets[,1] ],
                        j=propertyIDToIndex[ triplets[,2] ],
                        x=triplets[,3],
                        dims=c( length(itemIDs), length(propertyIDs) )  )
  rownames(smat) <- itemIDs
  colnames(smat) <- propertyIDs

  # I don't think we need the rules arrays. We can always re-create them if needed.
  #list( Matrix=smat, ItemIDToIndex=itemIDToIndex, PropertyIDToIndex=propertyIDToIndex )
  smat
}

#' Convert a sparse matrix to triplets data frame.
#' @description Converts a sparse matrix to triplets
#' @param smat a sparse matrix
#' @return a data frame of triplets 
#' @export
SparseMatrixToTriplets <- function( smat ) {
  # Use summary() over sparse matrix.
  # Then using rules over the indices.
  triplets <- summary(smat)

  # Rules
  if( !is.null(colnames(smat)) && !is.null(rownames(smat)) ) {
    rowRules <- 1:nrow(smat)
    names(rowRules) <- rownames( smat )
    colRules <- 1:ncol(smat)
    names(colRules) <- colnames( smat )
    triplets$i <- names( rowRules[ triplets$i ] )
    triplets$j <- names( colRules[ triplets$j ] )
  }

  triplets
}

#' Impose row ID's to a sparse matrix.
#' @description Makes sure that the rows of a matrix are in 1-to-1 correspondence to an array of row ID's
#' @param rowIDs an array of row ID's
#' @param smat a matrix with named rows
ImposeRowIDs <- function( rowIDs, smat ) {

  missingRows <- setdiff( rowIDs, rownames(smat) )
  nMissingRows <- length( missingRows )

  if ( nMissingRows > 0 ) {
    # Rows are missing in the matrix
    complMat <- sparseMatrix(i=c(1), j=c(1), x=c(0), dims = c( nMissingRows, ncol(smat) ) )

    rownames(complMat) <- missingRows
    colnames(complMat) <- colnames(smat)

    smat <- rBind( smat, complMat )
  }
  # At this point each element of rowIDs should have a corresponding row in the matrix
  smat[rowIDs,,drop=FALSE]
}

#' Impose column ID's to a sparse matrix.
#' @description Makes sure that the rows of a matrix are in 1-to-1 correspondence to an array of row ID's
#' @param colIDs an array of col ID's
#' @param smat a matrix with named columns
ImposeColumnIDs <- function( colIDs, smat ) {

  t( ImposeRowIDs( colIDs, t(smat)) )
}

#' Piecewise functon constructor.
#' @description Make piecewise function for a list of values.
#' The names of the values are used as function's result.
#' If the names are NULL they are automatically assign to be ordinals starting from 1.
#' Similar behavior is provided by the base function findInterval.
#' @param points a list of named values; if the values are not named automatic naming is used
#' @param tags the values to be returned for the ranges defined by points.
#' @details length(points) == length(tags) - 1
MakePiecewiseFunction <- function( points, tags=NULL ) {
  if ( length(points) ==0 || is.null(points) ) {
    warning("NULL of an empty list is given as an argument.", call.=TRUE )
    return( NULL )
  }
  if ( !is.numeric(points) ) {
    warning("The first argument is expected to be a numeric list.", call. =TRUE )
    return( NULL )
  }
  if ( !is.null(tags) && !is.numeric(tags) ) {
    warning("The second argument is expected to be NULL or a numeric list.", call.=TRUE )
    return( NULL )
  }

  points <- sort(points)

  if ( is.null( tags ) ) {
    tags <- 0:length(points)
  }

  funcStr <- paste( "function(x){ ( x <=" , points[1], " ) *", tags[1] )

  for( i in 1:(length(points)-1) ) {
    funcStr <- paste( funcStr, "+  (", points[i], "< x & x <=", points[i+1], ")*", tags[i+1] )
  }

  funcStr <- paste( funcStr, "+ (", points[length(points)], " < x )*", tags[length(points)+1], "}" )

  eval( parse( text=funcStr ) )
}

#' Multi-value column ingestion.
#' @param itemRows a data frame of flat content data
#' @param tagTypeColName column name of the relationship to be ingested inge in itemRows
#' @param itemIDName 
#' @param nTagsPerField number of tags per field of the column colName in itemRows
#' @export
IngestMultiValuedDataColumn <- function( itemRows, tagTypeColName, itemIDColName = "ID", nTagsPerField = 12, split = "," ) {

  spdf <- str_split_fixed( itemRows[, tagTypeColName], pattern = split, n=nTagsPerField )
  spdf <- as.data.frame( spdf, stringsAsFactors = FALSE )
  for( i in 1:ncol(spdf) ) {
    spdf[[i]] <- gsub( pattern = "^\\W", replacement = "", spdf[[i]] )
  }
  names( spdf ) <- paste( "tag", 1:nTagsPerField, sep="_" )

  tags.itemRows <- cbind( "id"=itemRows[[itemIDColName]], spdf )

  tags.itemRows$'tag_1'[ tags.itemRows$'tag_1' == "N/A" ] <- NA
  tags.itemRows <- tags.itemRows[ !is.na( tags.itemRows$'tag_1' ), ]

  ## In order to fit the sparse matrix creation
  tags <- unique( do.call(c, spdf) )
  tags <- data.frame( 'id'=1:length(tags), 'name'=tags[order(tags)] )
  tagToIDRules <- tags$id; names(tagToIDRules) <- tags$name
  for( i in 2:ncol(tags.itemRows) ) {
    tags.itemRows[[i]] <- tagToIDRules[ tags.itemRows[[i]] ]
  }
  names(tags.itemRows) <- c( "id", paste( "tag_id", 1:nTagsPerField, sep="_" ) )

  # result
  list( tags = tags, tags.items = tags.itemRows )
}

## For backward compatibility
IngestMovieDataColumn <- IngestMultiValuedDataColumn

#' Convert multi-column data frame into a sparse matrix.
#' @param Multi-column data frame id-tag relationship
#' @param idColName the column name of the item ID
#' @param tagTypeColNames names of the tag type column names 
#' @details This does not work if the tagTypeColNames have dash in them.
#' I assume because of the string-to-formula conversion in SMRCreateItemTagMatrix.
#' Obviously, the dependence of the SMRCreateItemTagMatrix can be removed.
#' @export
ConvertMultiColumnDataFrameToSparseMatrix <- function( multiColDF, itemColName, tagTypeColNames ) {

  emptyColumns <- laply( tagTypeColNames, function(tt) mean( is.na( multiColDF[,tt] ) ) == 1 )

  if ( sum( !emptyColumns ) < 1 ) {
    stop( "All tag columns are empty.", call. = TRUE )
  }
  tagTypeColNames <- tagTypeColNames[ !emptyColumns ]

  ## Find all the sub-matrices with for the tag types
  gmats <- llply( tagTypeColNames, function( tt ) {
    SMRCreateItemTagMatrix( dataRows = multiColDF, itemColumnName = itemColName, tagType = tt )
  } )

  ## Find all tags
  allTags <- unique( unlist( llply( gmats, colnames ) ) )
  allIDs <- unique( unlist( llply( gmats, rownames ) ) )

  ## Impose the tags to all tags matrices
  gmats <- llply( gmats, function(m) { ImposeRowIDs( allIDs, ImposeColumnIDs( allTags, m ) ) })

  ## Sum the tag matrices into one matrix
  gmat <- gmats[[1]]
  for( i in 2:length(gmats) ) { gmat <- gmat + gmats[[i]] }

  gmat
}


#' Make a matrix by column partitioning.
#' @description Make categorical representation of the numerical values of a column in a data frame and 
#' produce a matrix with the derived categorical tags as columns and values of a specified data column as rows. 
#' @param data a data frame
#' @param colNameForRows a column name in data for the rows of the result matrix
#' @param colNameForColumns a column name in data for the columns of the result matrix
#' @param breaks the points over which the breaking of data[colNameForColumns] is done
#' @param leftOverlap vector of weights for the neighboring columns to left
#' @param rightOverlap vector of weights for the neighboring columns to right
#' @param colnamesPrefix prefix for the columns names
#' @export
MakeMatrixByColumnPartition <- function( data, colNameForRows, colNameForColumns, breaks = 10, leftOverlap = NULL, rightOverlap = NULL, colnamesPrefix = "" ) {

  if( is.numeric( breaks ) && length( breaks ) == 1 ) {
    d0 <- min(data[[colNameForColumns]]); d1 <- max(data[[colNameForColumns]])
    breaks <- seq( d0, d1, (d1-d0)/(breaks-1) )
  }

  smat <- data[ , c(colNameForRows, colNameForColumns) ]
  qF <- MakePiecewiseFunction( breaks )
  smat <- cbind( smat, parts = laply( smat[[colNameForColumns]], qF ) )
  smat <- xtabs( as.formula( paste( "~", colNameForRows, "+ parts") ), smat, sparse = TRUE )
  colnames(smat) <- paste( colnamesPrefix, colnames(smat), sep="" )

  if ( !is.null( leftOverlap ) && !is.null( rightOverlap ) ) {
    genMat <- smat
  }

  if ( !is.null( leftOverlap ) ) {

    addMat <- smat
    zeroCol <- sparseMatrix(  i = c(1), j = c(1), x = 0, dims = c( nrow(smat), 1 ) )

    for( w in rev(leftOverlap) ) {
      addMat <- addMat[,2:ncol(addMat)]
      addMat <- cBind( addMat, zeroCol )
      smat <- smat + w * addMat
    }
  }

  if ( !is.null( rightOverlap ) ) {

    if ( is.null( leftOverlap ) ) { addMat <- smat } else { addMat <- genMat }

    zeroCol <- sparseMatrix(  i = c(1), j = c(1), x = 0, dims = c( nrow(smat), 1 ) )

    for( w in rightOverlap ) {
      addMat <- addMat[,1:(ncol(addMat)-1)]
      addMat <- cBind( zeroCol, addMat )
      smat <- smat + w * addMat
    }
  }

  smat
}

#' Convert to incidence matrix by column values.
#' @description Replaces each a column of a integer matrix with number of columns corresponding to the integer values.
#' The matrix [[2,3],[1,2]] is converted to [[0,0,1,0,0,0,0,1],[0,1,0,0,0,0,1,0]] .
#' @param mat an integer matrix to be converted to column value incidence matrix.
#' @param rowNames boolean to assign or not the result matrix row names to be the argument matrix row names
#' @param colNames boolean to assign or not the result matrix column names derived from the argument matrix column names
#' @export
ToColumnValueIncidenceMatrix <- function( mat, rowNames = TRUE, colNames = TRUE ) {

   tmat <- as( mat, "dgCMatrix")
   df <- summary(tmat)
   df <- data.frame(df)
   # minInt <- min(mat,na.rm = T); maxInt <- max(mat,na.rm = T)
   minInt <- min(tmat@x); maxInt <- max(tmat@x)
   #step <- maxInt - minInt + 1 ## this isincorrect df$j computed as  df$j <- ( df$j - 1 ) * step + df$x
   step <- maxInt + 1

   if( min(df$x) < 0 ) {
      warning( "The non-zero values of the matrix are expected to be non-negative integers.", call. = TRUE)
   }

   df$j <- ( df$j - 1 ) * step + df$x + 1
   ## In other words we are doing this:
   ## triplets <- ddply( .data = df, .variables = .(i,j),
   ##                   .fun = function(row) { c(row[[1]], (row[[2]]-1)*step + row[[3]] + 1, 1) })

   ## Convinient way to check the implmentation:
   ## resMat <- sparseMatrix( i = df$i, j = df$j, x = df$x, dims = c( nrow(mat), ncol(mat)*step ) )
   resMat <- sparseMatrix( i = df$i, j = df$j, x = rep(1,length(df$x)), dims = c( nrow(mat), ncol(mat)*step ) )
   
   if ( rowNames ) { rownames(resMat) <- rownames(mat) }

   if ( colNames ) { 
     colnames(resMat) <- as.character(unlist(Map( function(x) { paste(x, 0:maxInt, sep = ".") }, colnames(mat))))
   }
   
   resMat
}


##===========================================================
## Conversions to D3 network specifications
##===========================================================

SparseMatrixTripletsToD3NetworkSpec <- function( triplets ) {
  nodes <- unique(as.character(c(triplets[[1]],triplets[[2]])))
  rules <- setNames( seq(0,length(nodes)-1), nodes)
  triplets[[1]] <- as.integer( rules[ triplets[[1]] ] )
  triplets[[2]] <- as.integer( rules[ triplets[[2]] ] )
  list( Nodes = data.frame(name = nodes, stringsAsFactors = F), Links = setNames( as.data.frame(triplets), c("source","target","value") ) )
} 

SparseMatrixToD3NetworkSpec <- function( smat, smat2 = NULL ) {
  if( is.null(smat2) ) {
    SparseMatrixTripletsToD3NetworkSpec(SparseMatrixToTriplets(smat))
  } else {
    SparseMatrixTripletsToD3NetworkSpec( rbind( SparseMatrixToTriplets(smat), SparseMatrixToTriplets(smat2) ) )
  }
}

SparseMatrixListToD3NetworkSpec <- function( smats ) {
  
  SparseMatrixTripletsToD3NetworkSpec( do.call( rbind, Map( f = SparseMatrixToTriplets, smats ) ) )
  
}

SparseMatrixToD3NetworkSpecFirst <- function( smat ) {
  qMatNodes <- c(rownames(smat),colnames(smat))
  qMatNodes <- data.frame(name = qMatNodes, stringsAsFactors = F)
  rownames(smat) <- 0:(nrow(smat)-1)
  colnames(smat) <- nrow(smat) + (0:(ncol(smat)-1))
  qMatLinks <- setNames(as.data.frame(SparseMatrixToTriplets(smat)), c("source","target","value"))
  qMatLinks$source <- as.integer(qMatLinks$source)
  qMatLinks$target <- as.integer(qMatLinks$target)
  list( Nodes = qMatNodes, Links = qMatLinks)
}


##===========================================================
## Add date tags
##===========================================================

#' @description Aggregate values for given column names.
#' @param data a data frame
#' @param dateColumnName a date column over which the aggregation is done
AddDateTags <- function( data, dateColumnName ) {

  dateCol <- enquo(dateColumnName)

  qRes <-
  data %>%
    dplyr::mutate( DayBoundary = ceiling_date( !!dateCol, "days" ) ) %>%
    dplyr::mutate( MonthBoundary = ceiling_date( !!dateCol, "months" ) ) %>%
    dplyr::mutate( YearBoundary = ceiling_date( !!dateCol, "years" ) ) %>%
    dplyr::mutate( Month = months( !!dateCol ), Weekday = weekdays( !!dateCol ) ) %>%
    dplyr::mutate( Weekday = factor( Weekday, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ) ) ) %>%
    dplyr::mutate( Month = factor( Month, levels = c( "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" )  ) )

  qRes
}

##===========================================================
## Summary parititiong
##===========================================================

#' @description Print the summary of data frame in a series of specified number of columns.
#' @param data a data frame
#' @param numberOfColumns number of columns for the partitioning
SummaryPartitioned <- function( data, numberOfColumns = 3, ...) {

  k <- 1

  while( k <= ncol(data)) {
    if( k > 1 ) { cat("\n") }
    k1 <- min( ncol(data), k + numberOfColumns-1 )
    print( summary( data[, k:k1, drop=F ], ... ) )
    k <- k + numberOfColumns
  }
}
