"""Build the bundled English campaign with Python's standard library."""
import json
import math
import random
from pathlib import Path

# Each route lists the successive results, ending at the unmodified goal.
THEMES = [
    ("easy", "🍞", "Flour,Water,Salt,Yeast,Oats,Honey,Butter,Mixer", "Dough,Gluten Network,Rested Dough,Fermented Dough,Risen Dough,Shaped Loaf,Scored Loaf,Steamed Crust,Baked Loaf,Bread", "Rye,Wheat,Oat,Barley,Spelt,Seeded,Honey,Herb,Country,Sourdough"),
    ("easy", "🕯️", "Wax,Wick,Dye,Scent,Jar,Melting Pot,Mould,Thread", "Wax Flakes,Melted Wax,Scented Wax,Colored Wax,Primed Wick,Set Wick,Filled Mould,Cooled Wax,Trimmed Wick,Candle", "Linen,Rose,Cedar,Vanilla,Orange,Lavender,Pine,Mint,Amber,Citrus"),
    ("easy", "🪁", "Paper,Bamboo,String,Tape,Glue,Ribbon,Scissors,Ruler", "Kite Sketch,Cut Spar,Cross Spar,Wrapped Frame,Cut Sail,Taped Sail,Kite Tail,Bridle,Tensioned Line,Kite", "Diamond,Delta,Box,Star,Fish,Bird,Butterfly,Ribbon,Pocket,Stunt"),
    ("easy", "🪴", "Clay,Water,Soil,Seeds,Glaze,Sand,Kiln,Brush", "Clay Lump,Clay Base,Clay Coil,Open Vessel,Drainage Hole,Dried Vessel,Bisque Pot,Glazed Pot,Fired Planter,Plant Pot", "Herb,Fern,Moss,Cactus,Aloe,Ivy,Orchid,Basil,Jade,Succulent"),
    ("easy", "🍓", "Berries,Sugar,Pectin,Lemon,Jar,Spoon,Strainer,Stove", "Washed Berries,Crushed Fruit,Fruit Pulp,Sweetened Pulp,Simmering Syrup,Soft Gel,Fruit Preserve,Filled Jar,Sealed Jar,Jam", "Strawberry,Raspberry,Blueberry,Blackberry,Cherry,Plum,Peach,Apricot,Fig,Cranberry"),
    ("easy", "📓", "Paper,Thread,Cover,Glue,Needle,Cardboard,Ruler,Awl", "Trimmed Sheets,Folded Sheets,Paper Signature,Pierced Fold,Sewn Signatures,Book Block,Glued Spine,Book Cover,Bound Pages,Notebook", "Travel,Sketch,Field,Garden,Recipe,Study,Music,Poetry,Art,Science"),
    ("easy", "🥁", "Wood,Hide,Rope,Hoop,Glue,Peg,File,Mallet", "Wood Blank,Hollow Shell,Sanded Rim,Soaked Hide,Stretched Head,Drum Ring,Laced Head,Tuned Head,Resonance,Drum", "Hand,Frame,Snare,Bass,Marching,Practice,Parade,Jazz,Stage,Studio"),
    ("easy", "🧼", "Oil,Water,Scent,Dye,Mould,Bowl,Stirrer,Gloves", "Oil Blend,Warm Blend,Soap Base,Soap Batter,Colored Swirl,Scented Mix,Filled Tray,Set Block,Cured Bar,Soap", "Olive,Coconut,Lavender,Oat,Tea Tree,Aloe,Orange,Rosemary,Honey,Charcoal"),
    ("easy", "🪹", "Wood,Twig,Nail,Glue,Hammer,Saw,Roof Tile,Rope", "Plank,Marked Board,Cut Panel,Floor Panel,Side Wall,Entrance Hole,Joined Walls,Roof Panel,Hanging Loop,Birdhouse", "Oak,Pine,Cedar,Birch,Maple,Spruce,Bamboo,Willow,Cypress,Redwood"),
    ("easy", "🎨", "Pigment,Water,Brush,Paper,Gum,Palette,Jar,Sponge", "Ground Pigment,Color Paste,Diluted Color,Tinted Wash,First Wash,Wet Edge,Layered Wash,Painted Detail,Dry Painting,Watercolor", "Forest,Harbor,Mountain,Sunset,Desert,Garden,Meadow,Ocean,River,Lake"),
    ("normal", "🧭", "Iron,Wire,Magnet,Paper,Wood,Needle,Dial,Glass", "Iron Sliver,Ground Pin,Straight Needle,Polished Needle,Magnetized Needle,Pointer,North Mark,Dial Card,Pivot Pin,Needle Bearing,Mounted Pointer,Balanced Dial,Sealed Housing,True Bearing,Compass", "Hiking,Marine,Trail,Survey,Field,Pocket,Map,Cabin,Scout,Travel"),
    ("normal", "☂️", "Fabric,Wire,Shaft,Handle,Spring,Thread,Needle,Coating", "Canopy Pattern,Cut Gore,Sewn Gores,Coated Canopy,Wire Rib,Jointed Rib,Rib Cage,Sliding Ring,Locking Spring,Center Shaft,Attached Canopy,Sealed Seam,Grip Handle,Folded Canopy,Umbrella", "Rain,Sun,Patio,Garden,Travel,Pocket,Beach,Walking,Market,City"),
    ("normal", "🕰️", "Gear,Spring,Axle,Dial,Wood,Hand,Weight,Case", "Gear Blank,Toothed Wheel,Clock Arbor,Wound Spring,Drive Train,Escapement Wheel,Pallet Fork,Pendulum Rod,Balanced Pendulum,Minute Hand,Hour Gear,Face Plate,Calibrated Motion,Mounted Dial,Clock", "Mantel,Wall,Desk,Kitchen,Hall,Workshop,Station,Tower,Alarm,Analog"),
    ("normal", "🧵", "Yarn,Cotton,Wool,Shuttle,Loom,Dye,Comb,Scissors", "Fiber Bundle,Carded Fiber,Spun Thread,Dyed Thread,Warp Beam,Tensioned Warp,Loaded Shuttle,First Weft,Woven Strip,Edge Stitch,Trimmed Edge,Washed Cloth,Pressed Fabric,Finished Panel,Fabric Roll", "Cotton,Wool,Linen,Silk,Jute,Hemp,Canvas,Denim,Twill,Satin"),
    ("normal", "🚲", "Tube,Chain,Wheel,Pedal,Cable,Brake,Bearing,Seat", "Frame Drawing,Cut Tube,Welded Triangle,Painted Frame,Steering Tube,Front Fork,Spoked Hub,Trued Wheel,Inflated Tire,Chainring,Chain Drive,Brake Link,Installed Saddle,Aligned Wheels,Bicycle", "Road,Mountain,Touring,Trail,City,Cargo,Folding,Track,Gravel,Commuter"),
    ("normal", "🏮", "Glass,Wire,Paper,Lamp,Frame,Lens,Battery,Switch", "Lantern Sketch,Cut Frame,Frame Joint,Joined Frame,Glass Pane,Frosted Pane,Light Chamber,Socket,Wire Lead,Power Loop,On Switch,Mounted Lamp,Diffused Light,Protected Housing,Lantern", "Camp,Trail,Porch,Garden,Festival,Travel,Table,Signal,Paper,Window"),
    ("normal", "🎸", "Wood,String,Glue,Peg,Fret,Bridge,Saddle,Finish", "Tonewood,Soundboard Blank,Sound Hole,Braced Top,Bent Sides,Closed Body,Neck Blank,Truss Channel,Fretboard,Set Neck,Tuning Peg,Bridge Plate,Strung Body,Tuned Strings,Guitar", "Classical,Folk,Travel,Parlor,Studio,Stage,Jazz,Blues,Concert,Acoustic"),
    ("normal", "🛷", "Birch,Runner,Bolt,Rope,Wax,Seat,Saw,Clamp", "Bent Slat,Runner Blank,Curved Runner,Twin Runners,Seat Rails,Cross Braces,Drilled Mounts,Bolted Frame,Sanded Edge,Waxed Runner,Front Loop,Tow Rope,Tension Test,Level Glide,Sled", "Snow,Hill,Trail,Rescue,Freight,Winter,Ice,Camp,Field,Alpine"),
    ("normal", "💧", "Gravel,Sand,Carbon,Cloth,Bottle,Mesh,Valve,Tube", "Screen Mesh,Settling Cup,Washed Gravel,Rinsed Sand,Carbon Granules,Cloth Layer,Filter Bed,Intake Port,Outlet Port,Flow Control,Clear Sample,Flow Test,Sealed Cartridge,Fitted Housing,Water Filter", "Trail,Kitchen,Camp,Gravity,Countertop,Garden,Workshop,Household,Travel,Emergency"),
    ("normal", "📻", "Coil,Wire,Crystal,Diode,Spool,Earbud,Capacitor,Antenna", "Copper Windings,Tuning Coil,Resonant Circuit,Antenna Lead,Ground Return,Tuned Signal,Crystal Detector,Rectified Signal,Audio Envelope,Matching Coil,Earphone Jack,Mounted Circuit,Shielded Case,Received Broadcast,Radio", "Pocket,Marine,Trail,Kitchen,Desk,Weather,Travel,Workshop,Camp,Field"),
    ("hard", "🔭", "Lens,Mirror,Tube,Tripod,Clamp,Glass,Coating,Focuser", "Glass Blank,Ground Surface,Polished Surface,Optical Mirror,Reflective Coat,Primary Mirror,Mirror Cell,Secondary Mount,Secondary Mirror,Optical Tube,Beam Path,Image Plane,Eyepiece Lens,Focuser Rack,Optical Alignment,Star Test,Calibrated Focus,Tracking Mount,Sharp Image,Telescope", "Lunar,Planetary,Field,Survey,Portable,Stargazing,Deep Sky,School,Travel,Observatory"),
    ("hard", "🌉", "Cable,Steel,Concrete,Bolt,Beam,Tower,Deck,Anchor", "Soil Survey,Rock Footing,Foundation Form,Poured Footing,Tower Base,Tower Segment,Twin Towers,Anchor Block,Pilot Rope,Main Cable,Cable Saddle,Hanger Rod,Deck Truss,Deck Section,Joined Span,Expansion Joint,Load Sensor,Deck Balance,Load Test,Suspension Bridge", "River,Fjord,Harbor,Bay,Valley,Gorge,Coastal,Island,Footpath,Highway"),
    ("hard", "🌬️", "Blade,Copper,Magnet,Shaft,Tower,Bearing,Hub,Bolt", "Wind Survey,Blade Profile,Blade Mould,Cured Blade,Balanced Blade,Rotor Hub,Pitch Bearing,Assembled Rotor,Drive Shaft,Gearbox,Copper Stator,Magnet Rotor,Generator Case,Power Inverter,Control System,Nacelle,Tower Mount,Rotor Alignment,Grid Output,Wind Turbine", "Coastal,Offshore,Farm,Island,Field,Ridge,Valley,School,Remote,Harbor"),
    ("hard", "🛰️", "Panel,Sensor,Frame,Battery,Antenna,Motor,Shield,Camera", "Mission Plan,Orbit Model,Payload Layout,Frame Truss,Mounted Payload,Thermal Blanket,Power Bus,Solar Array,Battery Pack,Charge Controller,Flight Computer,Radio Module,Antenna Mount,Attitude Sensor,Control Wheel,Command Test,Shake Test,Vacuum Test,Beacon Signal,Satellite", "Weather,Ocean,Forest,Climate,Survey,Research,Mapping,Signal,Imaging,Education"),
    ("hard", "🌱", "Glass,Frame,Fan,Soil,Water,Sensor,Vent,Pump", "Site Plan,Ground Bed,Support Beam,Roof Frame,Glazed Wall,Sealed Joint,Air Intake,Roof Vent,Shade Screen,Plant Bed,Drip Line,Water Tank,Feed Pump,Soil Monitor,Climate Sensor,Fan Relay,Air Cycle,Irrigation Cycle,Growing Trial,Greenhouse", "Herb,Tomato,Seedling,Flower,Research,Garden,School,Market,Orchid,Winter"),
    ("hard", "🔬", "Lens,Slide,Mirror,Frame,Knob,Stage,Glass,Lamp", "Optical Drawing,Lens Blank,Ground Lens,Polished Lens,Coated Lens,Objective Pair,Condenser Lens,Light Path,Illuminated Stage,Slide Holder,Coarse Focus,Fine Focus,Focus Rack,Optical Column,Eyepiece Tube,Mounted Optics,Aligned Beam,Test Slide,Resolved Image,Microscope", "Field,School,Lab,Teaching,Workshop,Travel,Student,Research,Slide,Inspection"),
    ("hard", "🚁", "Motor,Frame,Propeller,Battery,Sensor,Board,Pad,Cable", "Airframe Plan,Carbon Plate,Arm Brace,Motor Mount,Motor Pair,Power Board,Speed Controller,Signal Lead,Flight Board,Motion Sensor,Control Loop,Radio Link,Propeller Hub,Matched Props,Battery Tray,Power Test,Motor Sync,Stable Hover,Flight Trial,Drone", "Survey,Mapping,Camera,Weather,Inspection,Rescue,Practice,Field,Studio,Forest"),
    ("hard", "🧊", "Tube,Compressor,Coil,Fan,Valve,Sensor,Panel,Seal", "Coolant Loop,Tubing Bend,Compressor Mount,Pressure Line,Condenser Coil,Heat Sink,Fan Duct,Filtered Air,Expansion Valve,Cold Coil,Drain Pan,Insulated Wall,Door Gasket,Sealed Cabinet,Thermostat,Control Relay,Airflow Test,Pressure Test,Stable Temperature,Refrigerator", "Kitchen,Lab,Clinic,Market,Pantry,Camp,Field,Office,Countertop,Workshop"),
    ("hard", "🚇", "Rail,Cable,Signal,Beam,Tunnel,Motor,Brake,Switch", "Route Survey,Track Map,Service Plan,Track Bed,Concrete Sleeper,Joined Rail,Track Switch,Signal Block,Power Rail,Feeder Circuit,Traction Motor,Brake Circuit,Carriage Shell,Platform Edge,Door Control,Train Signal,Timed Departure,Safety Trial,Passenger Service,Metro Line", "Airport,City,Harbor,Campus,Riverfront,North,South,East,West,Downtown"),
    ("hard", "🔋", "Cell,Copper,Panel,Wire,Fuse,Relay,Case,Sensor", "Cell Chemistry,Electrode Slurry,Coated Foil,Separator Film,Stacked Cell,Sealed Cell,Cell Test,Matched Cells,Series String,Busbar,Insulated Module,Pack Case,Protection Fuse,Current Sensor,Balance Circuit,Control Board,Charge Profile,Thermal Test,Rated Capacity,Battery Pack", "Solar,Trail,Backup,Marine,Workshop,Camp,Field,Robot,Portable,Emergency"),
    ("easy", "🍵", "Tea Leaf,Water,Kettle,Pot,Cup,Strainer,Lemon,Honey", "Sorted Leaves,Measured Leaves,Warmed Pot,Hot Water,Wetted Leaves,Steeped Leaves,Dark Infusion,Strained Liquor,Served Cup,Tea", "Mint,Jasmine,Ceylon,Chamomile,Green,Black,Oolong,Ginger,Rose,Hibiscus"),
    ("easy", "🧩", "Tile,Clay,Grout,Board,Glue,Marker,Sponge,Brush", "Tile Sketch,Marked Grid,Sorted Tiles,Trimmed Tiles,Dry Layout,Applied Adhesive,Set Tiles,Grouted Joints,Polished Surface,Mosaic", "Floral,Star,Ocean,Forest,Garden,Diamond,Harbor,Sun,Swirl,Mountain"),
    ("easy", "🌵", "Glass,Stone,Soil,Moss,Fern,Sand,Spray Bottle,Tweezers", "Clean Vessel,Drainage Layer,Charcoal Layer,Fitted Mesh,Soil Layer,Planting Hole,Positioned Fern,Mist Layer,Settled Planting,Terrarium", "Moss,Fern,Bonsai,Succulent,Desert,Woodland,Forest,Tropical,Ivy,Orchid"),
    ("easy", "🥞", "Flour,Milk,Egg,Sugar,Butter,Pan,Whisk,Spatula", "Dry Mix,Egg Mix,Loose Batter,Smooth Batter,Rested Batter,Greased Pan,Spread Batter,Set Edges,Flipped Cake,Pancake", "Berry,Oat,Banana,Apple,Honey,Cocoa,Lemon,Cinnamon,Vanilla,Buttermilk"),
    ("easy", "🔑", "Cord,Bead,Ring,Charm,Thread,Scissors,Pliers,Glue", "Cut Cord,Strung Bead,Formed Loop,Tight Knot,Fixed Bead,Crimp Ring,Opened Link,Fitted Charm,Closed Ring,Keychain", "Beaded,Wooden,Brass,Leather,Shell,Glass,Woven,Clay,Stone,Ribbon"),
    ("normal", "🪟", "Glass,Copper Foil,Lead Came,Solder,Flux,Pattern,Grozer,Glass Cutter", "Panel Drawing,Glass Template,Scored Glass,Cut Glass,Ground Edges,Dry Panel,Foiled Edge,Pressed Foil,Fluxed Joint,Spot Solder,Solder Seam,Framed Panel,Washed Panel,Polished Seam,Stained Glass Panel", "Rose,Geometric,Chapel,Window,Floral,Ocean,Mountain,Star,Forest,Sunburst"),
    ("normal", "🖋️", "Nib,Ink,Barrel,Feed,Cap,Clip,Spring,Seal", "Nib Blank,Shaped Nib,Split Tines,Smoothed Tip,Ink Channel,Capillary Feed,Mounted Nib,Ink Reservoir,Filled Reservoir,Sealed Collar,Pen Barrel,Cap Clip,Clean Nib,Flow Trial,Ink Pen", "Studio,Sketch,Desk,Travel,Drawing,Writing,Calligraphy,Pocket,Field,Office"),
    ("normal", "⚖️", "Beam,Pivot,Pan,Weight,Spring,Base,Dial,Pointer", "Level Base,Pivot Block,Fitted Pivot,Balance Beam,Pan Hook,Leveled Pans,Calibration Weight,Centered Beam,Pointer Arm,Zero Mark,Marked Dial,Aligned Pointer,Calibration Check,Test Reading,Mechanical Scale", "Kitchen,Market,Lab,Workshop,Parcel,Counter,Pantry,Trade,Postal,Balance"),
    ("normal", "☀️", "Foil,Mirror,Glass,Box,Insulation,Tray,Fastener,Thermometer", "Box Pattern,Cut Insulation,Insulated Box,Black Tray,Glass Cover,Sealed Rim,Folding Reflector,Reflective Face,Reflector Stand,Sun Angle,Focused Patch,Heat Chamber,Warmed Tray,Temperature Trial,Solar Cooker", "Camping,Kitchen,Field,Outdoor,School,Patio,Portable,Garden,Trail,Backyard"),
    ("normal", "🎶", "Cylinder,Comb,Gear,Spring,Crank,Case,Pin,Wood", "Cylinder Blank,Marked Cylinder,Pinned Cylinder,Toothed Comb,Tuned Comb,Spring Arbor,Wound Motor,Gear Reduction,Speed Governor,Rotating Cylinder,Timed Notes,Mounted Movement,Resonant Case,Play Test,Music Box", "Folk,Lullaby,Waltz,Holiday,Travel,Desk,Wooden,Cabinet,Studio,Concert"),
    ("hard", "💦", "Turbine,Valve,Pipe,Intake,Steel,Generator,Sensor,Gate", "Water Survey,Intake Plan,Screened Intake,Head Chamber,Penstock Segment,Sealed Penstock,Runner Profile,Cast Runner,Turbine Shaft,Mounted Runner,Flow Gate,Regulated Flow,Generator Coupling,Stator Windings,Control Cabinet,Oil Circuit,Load Balancing,Flow Trial,Electrical Output,Hydroelectric Generator", "River,Canal,Dam,Creek,Valley,Reservoir,Mountain,Farm,Island,Remote"),
    ("hard", "🌦️", "Sensor,Vane,Cup,Mount,Probe,Radio,Panel,Mast", "Site Survey,Leveled Base,Sensor Mast,Weather Shield,Temperature Probe,Humidity Probe,Pressure Cell,Rain Collector,Tipping Bucket,Wind Cups,Wind Vane,Sensor Bus,Clock Module,Data Logger,Solar Charger,Radio Link Test,Sensor Calibration,Sample Log,Weather Report,Weather Station", "Farm,Harbor,School,Field,Coastal,Mountain,Valley,Marine,Backyard,Remote"),
    ("hard", "🚰", "Pump,Valve,Membrane,Pipe,Gauge,Seal,Filter,Tank", "Water Intake,Screened Flow,Sediment Trap,Media Filter,Filtered Feed,High Pressure Pump,Pressure Gauge,Pressure Vessel,Membrane Sheet,Spiral Module,Sealed Module,Concentrate Stream,Permeate Stream,Flush Loop,Salt Monitor,Polished Water,Storage Tank,Water Quality Trial,Certified Water,Desalination Plant", "Coastal,Island,Marine,Harbor,Remote,Clinic,Town,Field,Emergency,Industrial"),
    ("hard", "🌊", "Float,Hull,Anchor,Rope,Battery,Sensor,Antenna,Lamp", "Drift Model,Hull Outline,Sealed Hull,Float Chamber,Ballast Block,Righting Test,Mooring Eye,Anchor Line,Swivel Joint,Sensor Cage,Wave Probe,Solar Mount,Charge Pack,Beacon Lamp,Data Radio,Antenna Mast,Salt Spray Trial,Water Trial,Telemetry Report,Ocean Buoy", "Weather,Wave,Harbor,Marker,Offshore,Survey,Coastal,Research,Channel,Warning"),
    ("hard", "🦾", "Motor,Gear,Encoder,Joint,Frame,Cable,Gripper,Sensor", "Motion Plan,Base Frame,Base Axis,Shoulder Link,Shoulder Drive,Elbow Link,Elbow Gear,Wrist Axis,Wrist Mount,Gripper Jaw,Mounted Gripper,Encoder Ring,Feedback Loop,Control Harness,Joint Limits,Motion Profile,Position Trial,Payload Test,Repeatability Trial,Robotic Arm", "Assembly,Lab,School,Workshop,Inspection,Sorting,Factory,Training,Research,Service"),
]
# Optional steps are authored for each theme. Each mask picks a complete route
# with five local choices, preserving dependencies and the final target.
ALTERNATIVES = [
    "Folded Dough,Cold-Proofed Dough,Pan Loaf,Misted Crust,Stone-Baked Loaf",
    "Warm Wax,Tinted Wax,Centered Wick,Chilled Wax,Finished Wick",
    "Bamboo Spar,Bound Frame,Stitched Sail,Loop Bridle,Set Line",
    "Pressed Base,Thrown Vessel,Air-Dried Vessel,Slip-Coated Pot,Fired Urn",
    "Mashed Berries,Spiced Pulp,Set Gel,Hot-Filled Jar,Sterile Seal",
    "Scored Sheets,Slotted Fold,Stitched Book Block,Cloth Cover,Pressed Pages",
    "Carved Shell,Steamed Hide,Tension Hoop,Even-Tension Head,Clear Tone",
    "Heated Oils,Whipped Batter,Scented Swirl,Chilled Block,Dried Bar",
    "Scored Board,Cut Base,Dowel Entrance,Vented Roof,Eye Hook",
    "Wet Paste,Gradient Wash,Damp Edge,Glazed Detail,Cured Wash",
    "Filed Pin,Honed Needle,Suspended Pointer,Ring Dial,Verified Heading",
    "Trimmed Panel,Bonded Canopy,Hinged Rib,Slide Collar,Collapsed Canopy",
    "Cut Gear,Coiled Spring,Pin Escapement,Swing Arm,Assembled Face",
    "Combed Fiber,Tinted Yarn,Fitted Warp,Woven Weft,Smoothed Cloth",
    "Bent Tube,Coated Frame,Tapered Fork,Centered Wheel,Track Alignment",
    "Bent Frame,Riveted Frame,Etched Pane,Lamp Base,Shielded Enclosure",
    "Carved Soundboard,Reinforced Top,Joined Body,Reinforced Neck,Intonated Strings",
    "Shaped Runner,Paired Runners,Reinforced Braces,Fastened Frame,Straight Glide",
    "Settling Bowl,Graded Sand,Pleated Layer,Inlet Screen,Mounted Cartridge",
    "Tapped Coil,Loop Antenna,Selected Signal,Smoothed Signal,Detected Broadcast",
    "Lapped Surface,Shaped Mirror,Coated Primary,Secondary Bracket,Resolved Star",
    "Drilled Footing,Reinforced Footing,Braced Tower,Cast Anchor,Proof Load",
    "Swept Blade,Composite Blade,Clamped Hub,Balanced Rotor,Regulated Output",
    "Orbit Estimate,Reinforced Frame,Heat Shield,Hinged Solar Panel,Telemetry Signal",
    "Raised Bed,Arched Roof,Weather Seal,Roof Shutter,Crop Trial",
    "Moulded Blank,Hand-Polished Lens,Matched Objectives,Illumination Path,Resolved Specimen",
    "Fiber Laminate,Printed Mount,Power Harness,Shielded Lead,Flight Check",
    "Coiled Tube,High Pressure Line,Finned Sink,Screened Intake,Stable Cooling",
    "Route Diagram,Graded Track Bed,Welded Rail,Interlocking Block,Trial Service",
    "Wet Slurry,Porous Separator,Crimped Cell,Balanced Cells,Measured Capacity",
    "Scooped Leaves,Heated Water,Long Infusion,Filtered Liquor,Poured Cup",
    "Scored Grid,Shaped Chips,Spread Mortar,Filled Joints,Buffed Surface",
    "Pebble Bed,Woven Barrier,Shallow Planting,Fine Mist,Rooted Planting",
    "Whisked Eggs,Folded Batter,Brushed Pan,Golden Edge,Turned Cake",
    "Threaded Beads,Double Knot,Pressed Crimp,Swivel Charm,Sealed Link",
    "Traced Template,Snapped Sheets,Lead Came Strip,Burnished Foil,Waxed Seam",
    "Filed Tip,Polished Point,Grooved Feed,Seated Nib,Writing Trial",
    "Machined Pivot,Equal Arm,Suspended Pans,Tared Beam,Certified Reading",
    "Foam Insert,Tinted Tray,Insulated Rim,Foil Mirror,Heat Trial",
    "Scored Drum,Tempered Comb,Clock Spring,Belt Reduction,Melody Trial",
    "Inlet Sketch,Settling Chamber,Gasketed Pipe,Carved Runner,Grid Trial",
    "Surveyed Pad,Vented Cover,Pressure Sensor,Measuring Cup,Forecast Log",
    "Settled Intake,Deep Media Bed,Booster Pump,Membrane Housing,Potable Sample",
    "Shaped Shell,Foam Float,Balance Trial,Reinforced Eye,Signal Report",
    "Cast Pedestal,Reinforced Shoulder,Elbow Beam,Belt Drive,Cycle Trial",
]
EDITIONS = "Original,Compact Series,Field Series,Workshop Series,Select Series,Heritage Series,Utility Series,Premium Series,Limited Series,Showcase Series".split(",")

def route_for(base, alternatives, mask):
    route = base.copy()
    for bit, (index, result) in enumerate(zip((1, 3, 5, 7, len(base) - 2), alternatives, strict=True)):
        if mask & (1 << bit):
            route[index] = result
    return route

STYLES = "Classic,Experimental,Compact,Custom,Standard,Deluxe,Limited Edition,Special,Prototype,Signature".split(",")
BATCHES = "Base,Sorted,Measured,Bench,Reserve,Prepared,Spare,Marked,Fitted,Selected,Packed,Sample,Tested,Workshop,Checked,Fresh,Refined,Support,Finished,Final".split(",")
STOCK = {
    "food": "Bowl,Tray,Scale,Sieve,Spoon,Water,Sugar,Salt,Thermometer,Pan,Jar,Cloth,Stove,Brush,Whisk,Timer",
    "mix": "Bowl,Tray,Jar,Scale,Sieve,Oil,Water,Dye,Spatula,Stirrer,Coating,Thermometer,Heat,Gloves,Pipette,Timer",
    "craft": "Paper,Glue,Tape,Scissors,Ruler,Thread,Cloth,Brush,Marker,Sponge,Cord,Cardboard,Blade,Clip,Tag,Mat",
    "wood": "Wood,Glue,Clamp,Saw,Chisel,Plane,File,Sandpaper,Stain,Brush,Cloth,Tape,Square,Strip,Pin,Bracket,Drill,Bit",
    "mech": "Frame,Tube,Plate,Fastener,Bolt,Nut,Washer,Clamp,Spacer,Rivet,Coupling,Cable,Pin,Seal,Bracket,Spring,Gauge,Caliper,Grease,Socket",
    "electric": "Wire,Cable,Board,Switch,Contact,Socket,Relay,Sensor,Diode,Terminal,Casing,Mount,Screw,Heat Sink,Signal Lead,Insulator,Test Probe,Connector,Fuse,Shield",
    "optics": "Glass,Prism,Screen,Plate,Spacers,Lens Cap,Mount,Tripod,Filter,Slide,Base,Mirror,Focus Ring,Light,Baffle,Clamp,Bracket,Lens Cloth,Shutter,Diffuser",
    "site": "Concrete,Steel,Beam,Gravel,Sand,Stake,Survey Tape,Level,Marking Paint,Channel,Cable,Fastener,Plate,Joint,Seal,Mesh,Clamp,Bracket,Anchor,Pipe",
    "plant": "Seed Tray,Soil,Pot,Water,Glass,Mesh,Shade Cloth,Tray,Dripper,Valve,Pipe,Filter,Fan,Vent,Seal,Temperature Probe,Timer,Controller,Support Pole,Irrigation Tube",
}
STOCK_BY_THEME = (
    "food mix craft mix food craft wood mix wood craft "
    "mech craft mech craft mech electric wood wood plant electric "
    "optics site mech electric plant optics electric mech site electric "
    "food craft plant food craft craft mech mech site mech site electric plant site mech"
).split()
DECOYS = "Badge,Receipt,Envelope,Sticker,Ticket,Bookmark,Label,Coupon,Keychain,Button,Card Sleeve,Token".split(",")
TOOLS = set("Mixer Melting Pot Scissors Ruler Kiln Brush Spoon Strainer Stove Needle Awl File Mallet Stirrer Gloves Hammer Saw Loom Shuttle Comb Tripod Clamp Focuser Lens Pump Compass".split())
ENERGY = set("Light Battery Charge Heat Power Current Signal".split())
SIZES = {"easy": (4, 10, 1), "normal": (8, 15, 2), "hard": (16, 20, 3)}
ICON = {"tool": "🛠️", "material": "📦", "component": "⚙️", "energy": "⚡", "phenomenon": "✨", "environment": "🌿"}

def attribute(word, default):
    if word in {"Soil", "Sand", "Gravel", "Wind", "Water"}:
        return "environment"
    if word in {"Resonance", "True Bearing", "Balanced Motion", "Received Broadcast"}:
        return "phenomenon"
    if any(part in ENERGY for part in word.split()):
        return "energy"
    if word in TOOLS or word.split()[-1] in TOOLS:
        return "tool"
    return default

def build():
    words = []
    ids = {}
    progress = {}
    stages = []
    root = Path(__file__).resolve().parents[1] / "assets"
    packs = root / "puzzles"
    packs.mkdir(exist_ok=True)

    def write_rows(path, rows):
        path.write_text(
            "[\n" + ",\n".join(
                json.dumps(row, ensure_ascii=False, separators=(",", ":")) for row in rows
            ) + "\n]\n",
            encoding="utf-8",
        )


    def card(word, kind, theme, score, emoji=None):
        if word not in ids:
            ids[word] = len(words)
            words.append([word, emoji or ICON[kind], kind])
            progress[word] = [0.0] * len(THEMES)
        progress[word][theme] = max(progress[word][theme], score)
        return ids[word]

    theme_positions = dict.fromkeys(SIZES, 0)
    theme_order = sorted(range(len(THEMES)), key=lambda index: list(SIZES).index(THEMES[index][0]))
    for theme in theme_order:
        difficulty, emoji, supplies, results, modifiers = THEMES[theme]
        theme_count = sum(entry[0] == difficulty for entry in THEMES)
        quota, extra = divmod(10000, theme_count)
        quota += theme_positions[difficulty] < extra
        theme_positions[difficulty] += 1
        size, depth, distractors = SIZES[difficulty]
        base = results.split(",")
        alternatives = ALTERNATIVES[theme].split(",")
        variants = modifiers.split(",")
        assert len(base) == depth and len(set(base + alternatives)) == depth + 5
        pack = []
        assert len(set(variants)) == len(STYLES) == 10
        pool = list(dict.fromkeys(supplies.split(",") + STOCK[STOCK_BY_THEME[theme]].split(",")))
        for variant, modifier in enumerate(variants):
            for style_index, style in enumerate(STYLES):
                for edition_index, edition in enumerate(EDITIONS):
                    slot = variant * 100 + style_index * 10 + edition_index
                    if slot >= quota:
                        break
                    rng = random.Random(theme * 1000 + slot)
                    route = route_for(base, alternatives, slot % 32)
                    edition_label = f" {edition}" if edition_index else ""
                    target = f"{style} {modifier} {route[-1]}{edition_label}"
                    assert target not in ids
                    target_id = card(target, "component", theme, 1.0, emoji)
                    rounds = []
                    for step, result in enumerate(route):
                        supply_count = size - int(step > 0)
                        batch = BATCHES[step]
                        available = [name for name in pool if f"{batch} {name}" not in route]
                        raw = rng.sample(available, supply_count)
                        ingredients = [
                            card(f"{batch} {name}", attribute(name, "material"), theme, .35)
                            for name in raw
                        ]
                        # The variant contributes a distinct ingredient to the first recipe.
                        if step == 0:
                            ingredients[0] = card(f"{modifier} Stock", "material", theme, .45)
                        if difficulty == "easy":
                            extras = [
                                card(f"{batch} {name}", "material", theme, .05)
                                for name in rng.sample(DECOYS, distractors)
                            ]
                        else:
                            # Near-miss supplies share the theme, but have visibly low goal relevance.
                            unused = [name for name in pool if name not in raw]
                            extras = [
                                card(f"Unsorted {batch} {name}", attribute(name, "component"), theme, .08)
                                for name in rng.sample(unused, distractors)
                            ]
                        assert len(set(ingredients + extras)) == supply_count + distractors
                        output = target_id if step == depth - 1 else card(
                            result, attribute(result, "component"), theme,
                            round(.4 + .55 * (step + 1) / depth, 3), emoji,
                        )
                        rounds.append([output, ingredients, extras])
                    stages.append([difficulty, target_id, theme, len(pack)])
                    pack.append(rounds)
        write_rows(packs / f"{theme}.json", pack)

    assert len(stages) == 30000 and len(words) >= 500
    with root.joinpath("stages.json").open("w", encoding="utf-8") as file:
        file.write("{\n")
        for index, (name, rows) in enumerate((("words", words), ("stages", stages))):
            if index:
                file.write(",\n")
            file.write(f'"{name}":[\n')
            for row_index, row in enumerate(rows):
                if row_index:
                    file.write(",\n")
                file.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")))
            file.write("\n]")
        file.write("\n}\n")
    vectors = {}
    target_ids = {stage[1] for stage in stages}
    for index, (word, _, _) in enumerate(words):
        fields = progress[word]
        # A shared final dimension gives sparse theme scores a consistent scale.
        if index not in target_ids:
            norm_sq = sum(value * value for value in fields)
            if norm_sq > .99:
                fields = [value * math.sqrt(.99 / norm_sq) for value in fields]
            fields.append(round(math.sqrt(max(0, 1 - sum(value * value for value in fields))), 5))
        else:
            fields.append(0)
        vectors[word] = [round(value, 5) if value else 0 for value in fields]
    root.joinpath("embeddings.json").write_text(
        "{\n" + ",\n".join(
            json.dumps(word) + ":" + json.dumps(vector, separators=(",", ":"))
            for word, vector in vectors.items()
        ) + "\n}\n"
    )
    print(f"{len(stages)} puzzles, {len(words)} distinct English labels")

if __name__ == "__main__":
    build()
