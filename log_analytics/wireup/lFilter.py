#!/usr/bin/python

import re
import os

# Filtering 
class lFilter:
    default_field = "LF_DEFAULT"
    class filter_int:
        def __init__(self, fields, obj, fid):
            self.fields = fields
            self.obj = obj
            self.fid = fid

    def __init__(self, jobid, regex, fdescr, hfield):
        self.jobid = jobid
        self.filters = { }
        self.template = re.compile(regex)
        self.template.match("test")
        self.fdescr = fdescr
        if( len(fdescr) == 0 ):
            print "ERROR: empty field data"
            os.abort();
        print fdescr.keys()[0]
        if (not ( hfield in fdescr.keys())):
            print "ERROR: hash field not found:"
            print "Hash Field = ", hfield
            print "Description: ", fdescr
            print "Using the first field, may not be efficient!: ", fdescr.keys()[0]
            self.hfield = fdescr.keys()[0]
        else:
            self.hfield = hfield

    def add(self, fields, obj, fid):
        if ( not (self.hfield in fields.keys())):
            print "Cannot import filter: hash field is not provided"
            os.abort()
        field = fields[self.hfield]
        f = self.filter_int(fields, obj, fid);
        if ( not (field in self.filters.keys()) ):
            self.filters[field] = []
        print "lFilter: Append to ", field, " fields = ", fields
        self.filters[field].append(f)


    def _parse_int(self, line):
        m = self.template.match(line)
        pline = {}
        if( m != None ):
            for field in self.fdescr.keys():
                pline[field] = m.group(self.fdescr[field])
        return pline


    def apply(self, line):
        pline = self._parse_int(line)
        if  ( float(pline["jobid"]) != self.jobid ) :
            print "DROP the line ", line
            return 0;
        h = pline[self.hfield]
        if( not (h in self.filters.keys())):
            print "Drop the line: no filter ", line
            return 0
        flist = self.filters[h]
        for flt in flist:
            ret = 0
            for field in flt.fields.keys():
                ret += (pline[field] != flt.fields[field] );
            if( not ret ):
                if( flt.obj.bfilter(pline, flt.fid) ):
                    return 1
        return 0
