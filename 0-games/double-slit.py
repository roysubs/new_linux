#!/usr/bin/env python3
import math
import os

def simulate_double_slit(screen_width, screen_height, slit_separation, screen_distance, wavelength):
    """
    Simulates the double-slit experiment and displays the interference pattern
    using ASCII graphics.

    Args:
        screen_width (int): The width of the simulation screen in characters.
        screen_height (int): The height of the simulation screen in characters.
        slit_separation (float): The distance between the centers of the two slits.
        screen_distance (float): The distance from the slits to the screen.
        wavelength (float): The wavelength of the simulated waves.
    """

    # Create a 2D array to represent the screen
    screen = [[' ' for _ in range(screen_width)] for _ in range(screen_height)]

    # Calculate the center of the screen
    center_y = screen_height // 2

    # Define ASCII characters for intensity levels (from low to high)
    intensity_chars = " .:-=+*#%@"

    # Calculate the intensity at each point on the screen
    for y in range(screen_height):
        # Calculate the vertical position on the screen relative to the center
        y_pos = (y - center_y) / screen_height * (screen_height / screen_width) * screen_distance # Scale y based on aspect ratio

        # Calculate the angle theta (approximation for small angles)
        # theta = math.atan(y_pos / screen_distance) # More accurate but might be slower

        # Calculate the path difference for a point on the screen
        # For a point (0, y_pos) on the screen and slits at (d/2, 0) and (-d/2, 0)
        # r1 = math.sqrt((y_pos - slit_separation/2)**2 + screen_distance**2)
        # r2 = math.sqrt((y_pos + slit_separation/2)**2 + screen_distance**2)
        # path_difference = abs(r1 - r2)

        # Using the approximation for far-field interference: path_difference = d * sin(theta) approx d * y_pos / screen_distance
        path_difference = slit_separation * y_pos / screen_distance


        # Calculate the phase difference
        phase_difference = (2 * math.pi * path_difference) / wavelength

        # Calculate the intensity at this point (proportional to cos^2(phase_difference / 2))
        # The formula for intensity is I = I_0 * cos^2(phi/2), where phi is the phase difference
        intensity = math.cos(phase_difference / 2)**2

        # Map the intensity to an ASCII character
        char_index = int(intensity * (len(intensity_chars) - 1))
        screen_row = screen[y] # Get the current row
        for x in range(screen_width):
            # In this simple 1D interference pattern, intensity only varies with y.
            # We fill the entire row with the same character based on the intensity at y.
             screen_row[x] = intensity_chars[char_index]
        screen[y] = screen_row # Update the row in the screen


    # Print the screen
    os.system('cls' if os.name == 'nt' else 'clear') # Clear console
    for row in screen:
        print("".join(row))

# --- Parameters ---
SCREEN_WIDTH = 80  # Width of the ASCII screen
SCREEN_HEIGHT = 40 # Height of the ASCII screen
SLIT_SEPARATION = 5.0 # Distance between slits (arbitrary units)
SCREEN_DISTANCE = 50.0 # Distance from slits to screen (arbitrary units)
WAVELENGTH = 1.0 # Wavelength of light (arbitrary units)

# Run the simulation
if __name__ == "__main__":
    print("Simulating Double Slit Experiment (Press Ctrl+C to exit)")
    simulate_double_slit(SCREEN_WIDTH, SCREEN_HEIGHT, SLIT_SEPARATION, SCREEN_DISTANCE, WAVELENGTH)

    # Keep the console open until user
    try:
        while True:
            pass
    except KeyboardInterrupt:
        print("\nSimulation ended.")
