#!/bin/sh

psql -U agrbrdf -d agrbrdf -h invincible -q -v run_name="'$1'" -v sample_name="'$2'" <<EOF
\t
select regexp_replace(regexp_replace(max(enzyme),'[/&]','-'),'ApeKI-MspI','MspI-ApeKI','i') from ((biosamplelist as bsl join biosamplelistmembershiplink as l on l.biosamplelist = bsl.obid) join biosampleob as s on s.obid = l.biosampleob ) join gbskeyfilefact as g on g.biosampleob = s.obid where bsl.listname = :run_name and s.samplename = :sample_name 
EOF