document.addEventListener("DOMContentLoaded", () => {
  {
    const sliders = document.getElementsByClassName(
      "__is_images_slides_container",
    );
    console.log({ sliders: sliders });
    for (const slider of sliders) {
      console.log({ slider: slider });
      slider.addEventListener("wheel", (event) => {
        console.log({ event: event });
        event.preventDefault();
        const sign = event.deltaY > 0 ? 1 : -1;
        slider.scrollLeft += sign * slider.offsetWidth;
      });
    }
  }

  {
    const globalObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const slideId = entry.target.getAttribute("id");

            // Находим кнопку, которая ведет именно на этот ID
            const currentLink = document.querySelector(
              `.__is_images_gallery_navbar a[href="#${slideId}"]`,
            );

            if (currentLink) {
              // Находим соседние кнопки только в ЭТОЙ же панели навигации и тушим их
              const siblingLinks =
                currentLink.parentElement.querySelectorAll("a");
              siblingLinks.forEach((link) => link.classList.remove("active"));

              // Подсвечиваем активную
              currentLink.classList.add("active");
            }

            // 2. МАГИЯ: ОБНОВЛЯЕМ АДРЕСНУЮ СТРОКУ БРАУЗЕРА
            // Проверяем, что такого хэша еще нет в URL, чтобы не перегружать процессор
            if (window.location.hash !== `#${slideId}`) {
              // replaceState плавно меняет хэш, не добавляя мусор в историю кнопке "Назад"
              history.replaceState(null, null, window.location.pathname); // `#${slideId}`);
            }
          }
        });
      },
      {
        threshold: 0.5, // Активен, если виден более чем на 50%
      },
    );

    // Просто запускаем слежку за вообще всеми слайдами на странице
    document
      .querySelectorAll(".__is_images_slide_figure")
      .forEach((slide) => globalObserver.observe(slide));
  }
});
