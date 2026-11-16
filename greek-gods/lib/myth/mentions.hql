/// A text naming a being: a passage of a work, dated by the work.
module myth.mentions for Mention : Evidence

import myth
import myth.works

/// A being named in a passage of a work.
type Mention { being : String, work : Work, passage : String }

fn subject(self) : String = self.being
fn dated(self) : Int = self.work.year
fn kind(self) : String = "text"
fn reference(self) : String = self.work.cite(self.passage)
