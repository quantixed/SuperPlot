# SuperPlot

Making SuperPlots in IGOR Pro.

[**Example**](#Example) | [**Workflow**](#Workflow) | [**Installation**](#Installation)

SuperPlots are described in:

Lord _et al._ SuperPlots: Communicating reproducibility and variability in cell biology. _J. Cell Biol._ (2020) 219(6): e202001064. doi:[10.1083/jcb.202001064](https://doi.org/10.1083/jcb.202001064)


## Example

An example SuperPlot generated using `SuperPlot.ipf` and the test data. Test data is taken from 

![img](img/exampleGraph.png?raw=true "image")

## Workflow

Execute using _Macros > Make SuperPlot_ menu item.

![img](img/menu.png?raw=true "image")

Select the three waves that correspond to replicates, treatment/condition, and measurement using the panel.

![img](img/panel.png?raw=true "image")

Click **Do It** to make your SuperPlot.

### Settings

The SuperPlot can be customised using the settings on the right of the panel.

- **Width** controls how wide the each cluster of points is on the x-axis.
- **Alpa** controls the tranparency of the individual data points. Auto mode lets Igor decide the transparency depending on data density.
- **Add bars** will add bars to show the mean ± 1 standard deviation to each condition, calculated from the averages of replicates, not from data points. See example above.
- **Add stats** will add p-values from a t-test for two conditions, or from Dunnett's post-hoc test for three or more conditions (compared to the first condition).

### Using your own data

Assemble your data in three waves where each row is a masurement for the entire dataset:

1. replicates (numeric wave) indicating which replicate the measurement is from
2. condition (text wave) indicating which condition/treatment/group the measurement corresponds to
3. measurement (numeric wave) the measurement taken

The waves can be named whatever you like and you can make more than one SuperPlot in an Igor experiment.

## Installation

To install, save a copy of `SuperPlot.ipf` and `PXPUtils.ipf` to *Wavemetrics/Igor Pro 8 User Files/User Procedures* or *Wavemetrics/Igor Pro 9 User Files/User Procedures*
This directory is usually in `~/Documents/`

Open `SuperPlot.ipf` in Igor by double-clicking it from Finder or selecting *File > Open File > Procedure* in a new Igor experiment.

If the code does not auto-compile, click *Macros > Compile*

`PXPUtils.ipf` can be found [here](https://github.com/quantixed/PXPUtils).

--

### Compatability

This code was developed on IGOR Pro 9 beta. It works on IP8+.