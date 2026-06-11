package com.forge.app.packaging

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PackageNameGeneratorTest {

    @Test
    fun `generated names are valid application IDs`() {
        val name = PackageNameGenerator.generate("My Cool App-12345")
        assertTrue(PackageNameGenerator.isValid(name))
        assertTrue(name.startsWith("com.forge.gen."))
    }

    @Test
    fun `generated names never start a segment with a digit`() {
        // Try a range of seeds and make sure the hash-derived segment is
        // always a legal Java identifier (segments can't start with 0-9).
        repeat(200) { i ->
            val name = PackageNameGenerator.generate("seed-$i")
            val lastSegment = name.substringAfterLast('.')
            assertTrue(
                "segment '$lastSegment' starts with a digit",
                lastSegment.first().isLetter()
            )
        }
    }

    @Test
    fun `same seed yields same package name (idempotent)`() {
        val a = PackageNameGenerator.generate("identical-seed")
        val b = PackageNameGenerator.generate("identical-seed")
        assertEquals(a, b)
    }

    @Test
    fun `different seeds yield different package names`() {
        val a = PackageNameGenerator.generate("app-one")
        val b = PackageNameGenerator.generate("app-two")
        assertNotEquals(a, b)
    }

    @Test
    fun `isValid rejects malformed package names`() {
        assertTrue(PackageNameGenerator.isValid("com.forge.gen.abc123"))
        org.junit.Assert.assertFalse(PackageNameGenerator.isValid("com"))
        org.junit.Assert.assertFalse(PackageNameGenerator.isValid("com.1forge.gen"))
        org.junit.Assert.assertFalse(PackageNameGenerator.isValid("com.forge..gen"))
        org.junit.Assert.assertFalse(PackageNameGenerator.isValid("com.forge.gen-x"))
    }
}
