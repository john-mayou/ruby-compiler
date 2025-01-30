let debounceTimer: number | null = null

async function main() {
    console.log('Building...')
    await build()
    console.log('Build complete.')

    console.log('Watching files...')
    const watcher = Deno.watchFs(['styles.scss', 'script.ts'])
    for await (const event of watcher) {
        if (event.kind === 'modify') {
            if (debounceTimer !== null) clearTimeout(debounceTimer)
            debounceTimer = setTimeout(async () => {
                console.log('Rebuilding...')
                await build()
                console.log('Rebuilding complete.')
            })
        }
    }
}

async function build() {
    await Promise.all([buildJs(), buildCss()])
}

async function buildJs() {
    console.log('Running JS build...')
    const process = new Deno.Command('deno', { args: ['run', 'build:js'] })
    const { success, stderr } = await process.output()
    if (!success) {
        console.error(`JS build failed: ${stderr}`)
        throw new Error(`JS build failed.`)
    } else {
        console.log('JS build successful.')
    }
}

async function buildCss() {
    console.log('Running CSS build...')
    const process = new Deno.Command('deno', { args: ['run', 'build:css'] })
    const { success, stderr } = await process.output()
    if (!success) {
        console.error(`CSS build failed: ${stderr}`)
        throw new Error(`CSS build failed.`)
    } else {
        console.log('CSS build successful.')
    }
}

main()