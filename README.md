# Ruby Flare

A command-line tool to extract relational data from semi-structured CSV files, based on a [paper by Microsoft Research](https://research.microsoft.com/pubs/214302/flashrelate-tech-report-April2014.pdf). Rules to extract data are written in a derivative of the paper's Flare language. 

## Usage

### Controlling the Input Format

`rflare` takes a list of CSV files to query, and uses the following options to work out how to parse them:

+ `-F`, `--field-separator` is the string used to separate fields, defaulting to `,`.
+ `-Q`, `--quote-char` is the character used to quote fields, defaulting to `"`.

### Specifying a Query

Queries are specified as graphs in the [Trivial Graph Format](https://en.wikipedia.org/wiki/Trivial_Graph_Format). The query is passed to `rflare` using exactly one of the following options:

+ `-f`, `--file` if the query graph is in a TGF file.
+ `-e`, `--evaluate` to specify a graph directly as an argument to `rflare`. This option uses a slightly modified TGF; a semi-colon (`;`) is used instead of a new-line `\n` to separate lines in the query.

### Field Selection Format

The field selection format is a way of specifying a one-dimensional positive (&ge; 0) possibly-infinite integer range. The start- and end-points of the range can either be absolute values or relative to the current position when the range is evaluated. Both the start and the end of the range are optional (defaulting to `-*` for the start point and `+*` for the end point), and are always separated by a `:`. If a single point with no `:` separator is given then the meaning is as follows:

|                  Specifier | Meaning  |
|----------------------------|----------|
| `1` (any finite absolute)  |    `1:1` |
| `+1` (any finite relative) |  `+1:+1` |
|                        `*` |   `0:+*` |
|                       `+*` |  `+1:+*` |
|                       `-*` |  `-*:-1` |

Each start- and end-point is relative to the current position if it starts with a `+` (further away from the origin than the current position) or `-` (closer to the origin). A `*` means the range extends as far as it can; a negative point (`-*`) means 0, and a positive point (`+*`) means infinity. An absolute point (e.g. `3`, `0`) doesn't begin with a sign, and indicates the 0-based field the range should start at.

Some examples, where `c` is the current position (not in the range), `C` is the current position (in the range), `x` is a field in the range and `_` is a field that's not in the range. The example formats are all applied horizontally; the field selection format itself doesn't specify whether a range is horizontal or vertical.

    +1 =>     _ _ _ c x _ _ _ _
    +1:+3 =>  _ _ _ c x x x _ _
    +0 =>     _ _ _ C _ _ _ _ _
    +2:* =>   _ _ _ c _ x x x x
    -1:+1 =>  _ _ x C x _ _ _ _
    -1:+1 =>  _ _ _ _ x C x _ _
    1:2 =>    _ x C _ _ _ _ _ _
    1:2 =>    _ x x c _ _ _ _ _
    1:2 =>    _ x x _ c _ _ _ _
    1:+2 =>   _ x x C x x _ _ _
    1:+2 =>   _ x x x C x x _ _
    -*:-2 =>  x x x x _ c _ _ _
    +* =>     _ _ _ c x x x x x
    * =>      x x x C x x x x x
    -* =>     x x x c _ _ _ _ _

### Query Format

Queries are specified as graphs, where each node in the graph matches a field in the input CSV, and each edge in the graph matches a relationship between fields. Each unique match of the graph (i.e. every node in the graph matches an input CSV field and each edge in the graph matches a relationship between the fields that the edge's nodes matched) outputs one CSV row.

In TGF, the first whitespace-delimited token of a *node* line is used as the node's id, and any remaining text on the line is its label. `rflare` uses the label to specify additional restrictions on what input CSV fields that the node can match:

+ The label (if not empty) must begin with a [Ruby regex](http://www.ruby-doc.org/core-2.1.1/Regexp.html); i.e. a regular expression between a leading `/` and a trailing `/`. If the label is empty the node matches using the regex `/.*/`.
+ Optionally, one or two field selectors can be specified, separated by whitespace. The first field selector always applies to rows, and the second (if present) always applies to columns. If either selector is missing, `0:*` is used.

In TGF, *edges* are directed; the first and second whitespace-delimited tokens of an edge line are the ids of the "from" and "to" nodes. The remaining text on the line is the edge's label, which is used to specify restrictions on the spatial relationship between the two nodes. The third token on the line (the first token of the label) is a field selector, that specifies the fields in the row that the "to" node can appear in (relative to the "from" node). The fourth token is a field selector that specifies what columns the "to" node can appear in (relative to the "from" node). If either selector is missing, `0:*` is used.

### The Matching Process

Each match starts by matching the *first node in the list*. A recursive algorithm then follow all the edges from the first node and tries to match the node at the end of the edge, and the edge itself. An edge could match in several ways (i.e. the node at the end could match several CSV fields, and, for each end node match, the edge matches too), for example the graph below:

    1 /a/
    2 /b/
    3 /c/
    #
    1 2 0 *
    2 3 0 +2:+3

With the following input CSV:

| col1 | col2 | col3 | col4 | col5 | col6 |
|------|------|------|------|------|------|
|   a  |   b  |   b  |   b  |   c  |   c  |

...the first node would produce three matches. Node `1` would always match `col1` of the first row, but node `2` could match the values in `col2`, `col3` and `col4`. For each of the node `2` matches, the edge would match (as the row relationship is `0` - and the node `2` matches are all on the same row as the node `1` matches - and the column constraint is `*` - and the node `2` matches are all within an unlimited horizontal absolute distance of the node `1` matches).

The algorithm continues recursively; for each matched graph it follows all the (unprocessed) edges from the matched set of nodes and tries to match the nodes at the other end of these edges. As with the first step, each matched graph could be dropped (if any of the unprocessed edges don't match) or could generate one or more matching graphs for the next recursive step. If we follow the example, after the first step we have the following matches:

    1 => col1, 2 => col2
    1 => col1, 2 => col3
    1 => col1, 2 => col4

The next step looks at all the edges reachable from the current matched graphs, and in the example each match only has one unprocessed edge; the edge between nodes `2` and `3`. If we consider the first match in the list, `1 => col1, 2 => col2`, we can see that node `3` can match `col5` or `col6`, but the edge `2 3 0 +2:+3` only matches when  `2 => col2, 3 => col5` as the horizontal distance between `col2` and `col6` is 4; outside the edge's relative horizontal constraint of `+2:+3` (`+2:+3` evaluated at `col2` gives fields `col4` and `col5`. If we repeat this step for the other two matches our current matches are now:

    1 => col1, 2 => col2, 3 => col5
    1 => col1, 2 => col3, 3 => col5
    1 => col1, 2 => col3, 3 => col6
    1 => col1, 2 => col4, 3 => col6

As no more edges are reachable from each of these match graphs, the matching process has finished and these four match graphs are outputted. This gives the output CSV:

| a | b | c |
| a | b | c |
| a | b | c |
| a | b | c |

### Controlling the Output Format

When a graph is matched, for each node in the query the value that node matches is printed. The output is in CSV format, with the same quote character and field separator as the input CSV files (as specified by the command line arguments). Nodes whose ids begin with an underscore (`_`) do not have their values printed in the column. In this case, the column is skipped entirely (i.e. two consective delimiters are *not* written).

## Examples

Some examples, using the data from the paper as the input CSV:

|          | value | year | value | year | Comments |
|----------|-------|------|-------|------|----------|
| Albania  |  1000 | 1950 |   930 | 1981 |   FRA 1  |
| Austria  |  3139 | 1951 |  3177 | 1955 |   FRA 3  |
| Belgium  |   541 | 1947 |   601 | 1950 |          |
| Bulgaria |  2964 | 1947 |  3259 | 1958 |   FRA 1  |
| Czech    |  2416 | 1950 |  2503 | 1960 |    NC    |

### Country Names 

Using row & column specifications a singe node. Graph (either in a file for `rflare`'s `--file` argument or direct specification via `--evaluate`):

    country, /^[A-Za-z]+$/ 1:* +0

Output:

|  Albania |
|  Austria |
|  Belgium |
| Bulgaria |
|    Czech |

### All the Values

A list of the "values" from both columns, by match cells with numbers that appear in columns headed "value". Graph (in a file, for `rflare`'s `--file` argument):

    value /^[0-9]+$/
    _valuecol /^value$/
    #
    value _valuecol -* +0

The graph in single line form, for `rflare`'s `--evaluate` format:

    value /^[0-9]+$/;_valuecol /^value$/;#;value _valuecol -* +0

Output:

| 1000 |
| 3139 |
|  541 |
| 2964 |
| 2416 |
|  930 |
| 3177 |
|  601 |
| 3259 |
| 2503 | 

### A Complex Example

The example from the paper; output the same data (minus the column headers) as the input CSV, but split the two pairs of value & year columns into two rows. Graph:

    country /^[A-Za-z]+$/ 1:* 0
    value /^[0-9]+$/ 1:*
    _valuecol /^value$/ 0
    year /^19[0-9]{2}$/ 1:*
    _yearcol /^year$/ 0
    comment /^[A-Za-z 0-9]*$/ 1:*
    _commentcol /^Comments$/ 0
    #
    value _valuecol -*
    year _yearcol -*
    comment _commentcol -*
    country value +0 +*
    value year +0 +1
    year comment +0 +*
    
Output:

| Albania  |  1000 | 1950 |   FRA 1  |
| Albania  |   930 | 1981 |   FRA 1  |
| Austria  |  3139 | 1951 |   FRA 3  |
| Austria  |  3177 | 1955 |   FRA 3  |
| Belgium  |   541 | 1947 |          |
| Belgium  |   601 | 1950 |          |
| Bulgaria |  2964 | 1947 |   FRA 1  |
| Bulgaria |  3259 | 1958 |   FRA 1  |
| Czech    |  2416 | 1950 |    NC    |
| Czech    |  2503 | 1960 |    NC    |

