% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ERTMon.R
\name{ERTMonMemberPresenceCheck}
\alias{ERTMonMemberPresenceCheck}
\title{General member presence check.}
\usage{
ERTMonMemberPresenceCheck(ertObj, memberName,
  memberPrettyName = memberName, functionName = "",
  logicalResult = FALSE)
}
\arguments{
\item{ertObj}{An ERTMon object.}

\item{memberName}{The name of the member to be checked.}

\item{memberPrettyName}{A pretty member name (for messages).}

\item{functionName}{The name of the delegating function.}

\item{logicalResult}{Should the result be logical value?}
}
\value{
A logical value or an ERTMon object.
}
\description{
A general function for checking the presence of a data member in an ERTMon object.
}
