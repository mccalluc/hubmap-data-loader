#!/usr/bin/env python3

import numpy as np
import pandas as pd
from pyimzml.ImzMLParser import ImzMLParser
import zarr

import argparse


class IMSDataset:
    """Converts IMS data stored as imzML into columnar or ndarray formats

    :param imzml_file: path to `.imzML` file.
    :param ibd_file: path to associated `.ibd` file.
    :param micro_res: microscopy resolution in nm (used for scaling).
    :param ims_res: IMS resolution in nm (used for scaling).
    """

    def __init__(self, imzml_file, ibd_file, micro_res, ims_res):
        # When passing the ibd path explicitly,
        # the file object must be opened manually
        self.parser = ImzMLParser(
            filename=imzml_file, ibd_file=open(ibd_file, "rb")
        )
        self.micro_res = micro_res
        self.ims_res = ims_res
        self.ims_px_in_micro = ims_res / micro_res  # scaling factor

        mz_lengths = self.parser.mzLengths
        if not (mz_lengths.count(mz_lengths[0]) == len(mz_lengths)):
            raise ValueError(
                "The number of m/z is not the same at each coordinate."
            )
        self.mzs, _ = self.parser.getspectrum(0)

    def __get_min_max_coords(self):
        coords = np.array(self.parser.coordinates)
        x_min, y_min, _ = np.min(coords, axis=0)
        x_max, y_max, _ = np.max(coords, axis=0)
        return x_min, y_min, x_max, y_max

    def __format_mzs(self, precision=4):
        return np.round(self.mzs, precision).astype(str)

    def to_columnar(self, dtype="uint32"):
        coords = np.array(self.parser.coordinates)
        x, y, _ = coords.T

        coords_df = pd.DataFrame(
            {
                "x": x,
                "y": y,
                "micro_x_topleft": x * self.ims_px_in_micro
                - self.ims_px_in_micro,
                "micro_y_topleft": y * self.ims_px_in_micro
                - self.ims_px_in_micro,
                "micro_px_width": np.repeat(self.ims_px_in_micro, len(coords)),
            },
            dtype=dtype,
        )

        intensities = np.zeros((len(coords_df), len(self.mzs)))
        for i in range(len(coords)):
            _, coord_intensities = self.parser.getspectrum(i)
            intensities[i, :] = coord_intensities

        intensities = pd.DataFrame(
            intensities, columns=self.__format_mzs(), dtype=dtype,
        )

        return coords_df.join(intensities)

    def to_array(self):
        x_min, y_min, x_max, y_max = self.__get_min_max_coords()
        arr = np.zeros(
            (x_max - x_min + 1, y_max - y_min + 1, self.parser.mzLengths[0])
        )

        for idx, (x, y, _) in enumerate(self.parser.coordinates):
            _, intensities = self.parser.getspectrum(idx)
            arr[x - x_min, y - y_min, :] = intensities

        return arr

    def write_zarr(self, path, dtype):
        arr = self.to_array()
        # zarr.js does not support compression yet
        # https://github.com/gzuidhof/zarr.js/issues/1
        z_arr = zarr.open(
            path, mode="w", shape=arr.shape, compressor=None, dtype=dtype
        )
        # write array with metadata
        z_arr[:, :, :] = arr
        x_min, y_min, x_max, y_max = self.__get_min_max_coords()
        z_arr.attrs["x_extent"] = [float(x_min), float(x_max)]
        z_arr.attrs["y_extent"] = [float(y_min), float(y_max)]
        z_arr.attrs["scaling_factor"] = self.ims_px_in_micro
        z_arr.attrs["mz"] = self.__format_mzs().tolist()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Create zarr from Spraggins dataset."
    )
    parser.add_argument(
        "--imzml_file",
        required=True,
        help="imzML file from Jeff Spraggins' lab.",
    )
    parser.add_argument(
        "--ibd_file",
        required=True,
        help="Corresponding ibd file from Jeff Spraggins' lab",
    )
    parser.add_argument(
        "--ims_file",
        required=True,
        help="Write the IMS data to this zarr file.",
    )
    args = parser.parse_args()
    dataset = IMSDataset(
        args.imzml_file, args.ibd_file, micro_res=0.5, ims_res=10
    )
    dataset.write_zarr(args.ims_file, dtype="i4")
