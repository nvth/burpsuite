<a id="readme-top"></a>

<br />
<div align="center">
  <a href="https://github.com/nvth/BurpActivator">
    <img src="img/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">BurpSuite Pro Compatibility Pack</h3>

  <p align="center">
    This product is not a medicine and is not intended to replace medical treatment!
    <br />
    <a href="https://github.com/nvth/BurpActivator?tab=readme-ov-file"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/nvth/BurpActivator/releases">Release</a>
    ·
    <a href="https://github.com/nvth/BurpActivator/issues/new?labels=bug">Report Bug</a>
    ·
    <a href="https://github.com/nvth/BurpActivator/issues/new?labels=question">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

[![Product Name Screen Shot][product-screenshot]](https://github.com/nvth/BurpActivator)

This is Burpsuite Pro Pack.

Here's why:
* Save your money
* Funny to use :smile:

Hope y'all enjoy it!

_Thanks Dr.FarFar for this loader_
<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

Builder:

[![java][java]][java] [![chatgpt][chatgpt]][chatgpt]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

The following steps must be followed.

### Prerequisites

Requirements:
* Windows: Run PowerShell as Administrator
* Linux: Run with sudo/root privileges
* Java 21 installed

### Installation
Clone the repo
   ```sh
    git clone https://github.com/nvth/burpsuite.git
   ```
#### Windows

1. Requirements
 - JDK 21 installed (script can install OpenJDK 21 if missing)
2. Open PowerShell as Administrator (required)
    ```s
    Set-ExecutionPolicy RemoteSigned
    Set-ExecutionPolicy Unrestricted
    ```
    Run `install.ps1`

    Revert the execution policy (optional)
    ```s
    Set-ExecutionPolicy Default
    ```
    Files are installed to:
    - `C:\burpsuite_nvth\bin` (launchers: `burp.bat`, `BurpSuiteProfessional.vbs`)
    - `C:\burpsuite_nvth\data` (downloads: `burpsuite_pro.jar`, `loader.jar`, JDK installer, icon)
    Uninstall script: `C:\burpsuite_nvth\uninstall.ps1` (removes the entire `C:\burpsuite_nvth` folder)
3. Activation and Start Menu shortcut

   See [capsule_windows.md](capsule_windows.md) for the full, illustrated steps.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

#### Linux/Ubuntu

1. Requirements
 - Run with sudo/root privileges
 - Java 18 or 21 (script can install OpenJDK 21 if missing)
2. Run the installer
   ```sh
   sudo bash install-linux.sh
   ```
   The script will download required files, set up Java (if needed),
   create a launcher and a desktop shortcut.
3. Files are installed to:
   - `<repo>/burpsuite_nvth/bin` (launcher: `burp`)
   - `<repo>/burpsuite_nvth/data` (downloads: `burpsuite_pro.jar`, `loader-ubuntu.jar`, JDK, icon)
   - `~/.local/share/applications/BurpSuiteProfessional.desktop` (desktop shortcut)
   - `/usr/local/bin/burp` (symlink; falls back to `~/.local/bin/burp` if no sudo)
   - Uninstall script: `<repo>/burpsuite_nvth/uninstall.sh`
4. Auto-start after install
   Before the script finishes, it will automatically open `loader-ubuntu.jar`
   and then launch `burpsuite_pro.jar` to activate.
5. After activate, on terminal, type `burp`, happy hacking.

<!-- USAGE EXAMPLES -->
## Usage

Script all in one update soon.

_For more examples, please refer to the [Documentation](https://example.com)_

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ROADMAP -->
## Roadmap

- [x] Add Changelog
- [x] Add back to top links
- [ ] Add "components" document to easily copy & paste sections of the readme
- [ ] Multi-language Support
    - [ ] English
    - [ ] Vietnamese

See the [open issues](https://github.com/nvth/BurpActivator/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b `)
3. Commit your Changes (`git commit -m `)
4. Push to the Branch (`git push origin `)
5. Open a Pull Request

### Top contributors:

<a href="https://github.com/nvth/burpsuite/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=nvth/burpsuite" alt="contrib.rocks image" />
</a>

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

kevin - [@kevin](https://twitter.com/) - email@kevin.com

Project Link: [https://github.com/nvth/burpsuite](https://github.com/nvth/burpsuite)

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributors-url]: https://github.com/nvth/burpsuite/graphs/contributors

[forks-url]: https://github.com/othneildrew/Best-README-Template/network/members
[stars-url]: https://img.shields.io/github/stars/nvth/burpsuite
[issues-url]: https://github.com/nvth/burpsuite/issues
[license-url]: https://github.com/nvth/burpsuite/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/#
[product-screenshot]: img/image.png
[java]: https://img.shields.io/badge/Java-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white
[chatgpt]: https://img.shields.io/badge/ChatGPT-75a99c?logo=OpenAI&logoColor=white
