'use strict'

type FormattedMap = Record<string, string>

const formatted_res = await fetch('/formatted.json')
const formatted_map: FormattedMap = await formatted_res.json()

for (const [golden, formatted] of Object.entries(formatted_map)) {
    const jsCodeBlock = document.getElementById(`js-${golden}`) as HTMLElement | null
    if (jsCodeBlock === null) continue

    const unformatted = jsCodeBlock.textContent || ''
    const updateText = (text: string) => jsCodeBlock.innerText = text

    jsCodeBlock.addEventListener('mouseenter', (_event: MouseEvent) => {
        updateText(formatted)

        const onFinish = (_event: MouseEvent) => {
            updateText(unformatted)
            jsCodeBlock.removeEventListener('mouseleave', onFinish)
        }

        jsCodeBlock.addEventListener('mouseleave', onFinish)
    })
}
