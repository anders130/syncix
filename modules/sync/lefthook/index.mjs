import { yamlPatch } from 'syncix'

export const writeHandlers = {
    'lefthook.yml': yamlPatch('lefthook.yml'),
}
