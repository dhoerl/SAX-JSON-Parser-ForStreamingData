SAX-JSON-Parser-ForStreamingData
================================

### CHANGE LOG:
 - 1.0.0 2/26/2014  First Release

### DESCRIPTION

Parse JSON arrays as they download, convert each object to native using NSJSONSerialization, and return it to a delegate.

As you probably know, iOS does not provide a streaming JSON parser—you normally need to save all the data, and keep the user waiting, while you store, then process, data. Wouldn't it be so much nicer to start showing the user the data in say a table, while its being downloaded?

Not only does this class facilitate downloading and converting JSON data, but it works with **MongoDB** style-JSON, where you have **objectID** and **new date()**  objects, that cause ``NSJSONSerialization`` fits (ie, it won't parse). What the class does is to extract the ID, replace the text with a simple string containing the ID, and overwrites extra bytes with spaces.

Likewise, **new date()** objects can be processed, and an ISO formatted date string generated to replace them. Note that in this code, all dates where of a single format. If your MongoDB repository has multiple formats, you will need to enhance the date processing, or just return the enclosed date stings, and process them later.

The process works by mallocing and reallocing memory until it has enough to hold the first object, and subsequently reallocs just enough memory to hold the current in-process object (plus any residual bytes in the last received packet). As each object is detected, the bytes are passed to ``NSJSONSerialization`` and the output stored in a mutable array.

Everytime an object is detected, all trailing bytes in the temporary array are moved to the start, and the detection process repeated. When all data bytes are processed, if one or more objects were created, they get sent to the delegate.

The demo app (and unit test) reads data from the text file `JSON.txt` (the list ofmy github repository projects in JSON format), and feeds it to the parser in small chunks with some small delay between each chunk (to simulate a network download).

### UNIT TEST

The sole unit test runs a million loops, where it creates an object and sends random chunks of data, from 1 to 256 bytes, to verify that some particular "break" in the data does not cause problems. The initial converted array is compared to the pre-computed one to insure not a single byte is different.

### FUTURES

A second demo target that actually uses the network to download data.

### CREDITS

Much of this code was derived from code I developed at *Sailthru* (www.sailthru.com), who allowed me to cherry pick some of it for open sourcing here.

### LICENSE

This code is subject to the *Apache License*, included with this distribution.