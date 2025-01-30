'use strict'

type FormattedMap = Record<string, string>

const formatted_res = await fetch('/formatted.json')
const formatted_map: FormattedMap = await formatted_res.json()

for (const [golden, formatted] of Object.entries(formatted_map)) {
    const codeBlock = document.getElementById(`js-${golden}`) as HTMLElement | null
    if (codeBlock === null) continue

    const unformatted = codeBlock.textContent || ''
    const updateText = (text: string) => codeBlock.innerText = text

    codeBlock.addEventListener('mouseenter', (_event: MouseEvent) => {
        updateText(formatted)

        const onFinish = (_event: MouseEvent) => {
            updateText(unformatted)
            codeBlock.removeEventListener('mouseleave', onFinish)
        }

        codeBlock.addEventListener('mouseleave', onFinish)
    })
}
